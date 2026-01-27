# ==========================================
# 1. PREPARACIÓN DEL CÓDIGO (ZIPs individuales)
# ==========================================

data "archive_file" "ingestion_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/lambda_ingestion.py"
  output_path = "${path.module}/functions/lambda_ingestion.zip"
}

data "archive_file" "process_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/process_reservation.py"
  output_path = "${path.module}/functions/process_reservation.zip"
}

# ==========================================
# 2. CONFIGURACIÓN DE LAMBDA: INGESTIÓN (API)
# ==========================================

resource "aws_lambda_function" "ingestion" {
  function_name = "${var.project_name}-ingestion-${var.environment}"
  role          = var.lambda_ingestion_role_arn
  handler       = "lambda_ingestion.handler"
  runtime       = "python3.13"

  filename         = data.archive_file.ingestion_zip.output_path
  source_code_hash = data.archive_file.ingestion_zip.output_base64sha256

  environment {
    variables = {
      INVENTORY_TABLE    = var.inventory_table_name
      RESERVATIONS_TABLE = var.reservations_table_name
      EVENT_BUS_NAME     = var.event_bus_name
    }
  }
}

# ==========================================
# 3. CONFIGURACIÓN DE LAMBDA: PROCESAMIENTO (WORKER)
# ==========================================

resource "aws_lambda_function" "process_reservation" {
  function_name = "${var.project_name}-process-reservation-${var.environment}"
  role          = var.lambda_ingestion_role_arn
  handler       = "process_reservation.handler"
  runtime       = "python3.13"

  filename         = data.archive_file.process_zip.output_path
  source_code_hash = data.archive_file.process_zip.output_base64sha256

  environment {
    variables = {
      INVENTORY_TABLE    = var.inventory_table_name
      RESERVATIONS_TABLE = var.reservations_table_name
    }
  }
}

# ==========================================
# 4. TRIGGER: CONEXIÓN SQS -> LAMBDA WORKER
# ==========================================

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.reservation_queue_arn
  function_name    = aws_lambda_function.process_reservation.arn
  batch_size       = 5
}

# ==========================================
# 5. CONFIGURACIÓN DE API GATEWAY (HTTP API)
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

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ingestion.invoke_arn
}

resource "aws_apigatewayv2_route" "reserve_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /reserve"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}