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

data "archive_file" "payment_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/lambda_payment.py"
  output_path = "${path.module}/functions/lambda_payment.zip"
}

# ==========================================
# 2. CONFIGURACIÓN DE LAMBDAS
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
      STATE_MACHINE_ARN  = aws_sfn_state_machine.reservation_flow.arn
    }
  }
}

resource "aws_lambda_function" "payment" {
  function_name = "${var.project_name}-payment-${var.environment}"
  role          = var.lambda_ingestion_role_arn
  handler       = "lambda_payment.handler"
  runtime       = "python3.13"
  filename         = data.archive_file.payment_zip.output_path
  source_code_hash = data.archive_file.payment_zip.output_base64sha256

  environment {
    variables = {
      RESERVATIONS_TABLE = var.reservations_table_name
    }
  }
}

# ==========================================
# 3. TRIGGER SQS Y API GATEWAY BASE
# ==========================================

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.reservation_queue_arn
  function_name    = aws_lambda_function.process_reservation.arn
  batch_size       = 5
}

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

# ==========================================
# 4. INTEGRACIONES Y RUTAS (NOMBRES ORIGINALES)
# ==========================================

# Integración Ingesta (Original)
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ingestion.invoke_arn
}

# Integración Pago (Nueva)
resource "aws_apigatewayv2_integration" "payment_integration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.payment.invoke_arn
}

# Ruta Reserva (Original)
resource "aws_apigatewayv2_route" "reserve_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /reserve"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Ruta Pago (Nueva)
resource "aws_apigatewayv2_route" "payment_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /pay"
  target    = "integrations/${aws_apigatewayv2_integration.payment_integration.id}"
}

# ==========================================
# 5. PERMISOS (NOMBRES ORIGINALES)
# ==========================================

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_payment" {
  statement_id  = "AllowExecutionFromAPIGatewayPayment"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.payment.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ==========================================
# 6. STEP FUNCTIONS (SIN CAMBIOS)
# ==========================================

resource "aws_sfn_state_machine" "reservation_flow" {
  name     = "${var.project_name}-reserve-flow-${var.environment}"
  role_arn = var.sfn_role_arn

  definition = jsonencode({
    Comment = "Espera 30s y libera el asiento si no se ha pagado"
    StartAt = "Esperar30Segundos"
    States = {
      "Esperar30Segundos" = {
        Type    = "Wait"
        Seconds = 30
        Next    = "VerificarStatus"
      },
      "VerificarStatus" = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:getItem"
        Parameters = {
          TableName = var.reservations_table_name
          Key = {
            ReservationID = { "S.$" : "$.reservationId" }
          }
        }
        ResultPath = "$.db_result"
        Next       = "EstaPagado"
      },
      "EstaPagado" = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.db_result.Item.status.S"
            StringEquals = "CONFIRMED"
            Next         = "FinalizarExito"
          }
        ]
        Default = "LiberarAsiento"
      },
      "LiberarAsiento" = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:updateItem"
        Parameters = {
          TableName = var.inventory_table_name
          Key = {
            EventID = { "S.$" : "$.db_result.Item.EventID.S" }
            SeatID  = { "S.$" : "$.db_result.Item.SeatID.S" }
          }
          UpdateExpression = "SET #s = :available"
          ExpressionAttributeNames  = { "#s" : "status" }
          ExpressionAttributeValues = { ":available" : { "S" : "AVAILABLE" } }
        }
        Next = "MarcarExpirada"
      },
      "MarcarExpirada" = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:updateItem"
        Parameters = {
          TableName = var.reservations_table_name
          Key = {
            ReservationID = { "S.$" : "$.reservationId" }
          }
          UpdateExpression = "SET #s = :expired"
          ExpressionAttributeNames  = { "#s" : "status" }
          ExpressionAttributeValues = { ":expired" : { "S" : "EXPIRED" } }
        }
        End = true
      },
      "FinalizarExito" = {
        Type = "Succeed"
      }
    }
  })
}