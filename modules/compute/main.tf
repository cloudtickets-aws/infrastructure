# ==========================================
# 1. PREPARACIÓN DEL CÓDIGO (ZIP)
# ==========================================

data "archive_file" "lambda_zip" {
  type        = "zip"
  # Apuntamos a la nueva carpeta functions
  source_file = "${path.module}/functions/lambda_ingestion.py"
  output_path = "${path.module}/functions/lambda_ingestion.zip"
}

# ==========================================
# 2. CONFIGURACIÓN DE AWS LAMBDA
# ==========================================

resource "aws_lambda_function" "ingestion" {
  function_name = "${var.project_name}-ingestion-${var.environment}"
  role          = var.lambda_ingestion_role_arn
  handler       = "lambda_ingestion.handler" # archivo.función
  runtime       = "python3.13"

  # Archivo físico del ZIP
  filename         = data.archive_file.lambda_zip.output_path
  
  # Esta línea es CLAVE: detecta cambios en el código para re-desplegar
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      INVENTORY_TABLE    = var.inventory_table_name
      RESERVATIONS_TABLE = var.reservations_table_name
      EVENT_BUS_NAME     = var.event_bus_name  # <-- La Lambda ya sabrá a donde disparar
    }
  }
}

# ==========================================
# 3. CONFIGURACIÓN DE API GATEWAY (HTTP API)
# ==========================================

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"] 
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

# Integración: Une la API con la Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ingestion.invoke_arn
}

# Ruta: POST /reserve
resource "aws_apigatewayv2_route" "reserve_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /reserve"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Permiso para que la API pueda "despertar" a la Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}