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

data "archive_file" "pdf_generator_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/pdf_generator.py"
  output_path = "${path.module}/functions/pdf_generator.zip"
}

data "archive_file" "notification_zip" {
  type        = "zip"
  source_file = "${path.module}/functions/lambda_notification.py"
  output_path = "${path.module}/functions/lambda_notification.zip"
}

# ==========================================
# 2. CONFIGURACIÓN DE LAMBDAS (CAPA LÓGICA)
# ==========================================

# Lambda: Ingesta de API
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

# Lambda: Procesador de SQS a Step Functions
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

# Lambda: Simulador de Pago
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

# Lambda: Generador de PDF
resource "aws_lambda_function" "pdf_generator" {
  function_name = "${var.project_name}-pdf-generator-${var.environment}"
  role          = var.lambda_ingestion_role_arn
  handler       = "pdf_generator.handler"
  runtime       = "python3.13"
  filename         = data.archive_file.pdf_generator_zip.output_path
  source_code_hash = data.archive_file.pdf_generator_zip.output_base64sha256

  environment {
    variables = {
      TICKETS_BUCKET = var.tickets_bucket_name
      EVENT_BUS_NAME = var.event_bus_name
    }
  }
}

# Lambda: Notificaciones (Email/SES)
resource "aws_lambda_function" "notification" {
  function_name = "${var.project_name}-notification-${var.environment}"
  role          = var.lambda_ingestion_role_arn
  handler       = "lambda_notification.handler"
  runtime       = "python3.13"
  filename         = data.archive_file.notification_zip.output_path
  source_code_hash = data.archive_file.notification_zip.output_base64sha256

  environment {
    variables = {
      RESERVATIONS_TABLE = var.reservations_table_name
    }
  }
}

# ==========================================
# 3. TRIGGERS SQS (CONEXIÓN DE COLAS)
# ==========================================

# Trigger: Cola de Reservas -> Procesador
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.reservation_queue_arn
  function_name    = aws_lambda_function.process_reservation.arn
  batch_size       = 5
}

# Trigger: Cola de PDF -> Generador
resource "aws_lambda_event_source_mapping" "pdf_trigger" {
  event_source_arn = var.pdf_queue_arn
  function_name    = aws_lambda_function.pdf_generator.arn
  batch_size       = 1
}

# Trigger: Cola de Notificación -> Notificador
resource "aws_lambda_event_source_mapping" "notification_trigger" {
  event_source_arn = var.notification_queue_arn
  function_name    = aws_lambda_function.notification.arn
  batch_size       = 5
}

# ==========================================
# 4. API GATEWAY (HTTP API)
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

resource "aws_apigatewayv2_integration" "payment_integration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.payment.invoke_arn
}

resource "aws_apigatewayv2_route" "reserve_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /reserve"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "payment_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /pay"
  target    = "integrations/${aws_apigatewayv2_integration.payment_integration.id}"
}

# ==========================================
# 5. PERMISOS DE INVOCACIÓN (LAMBDA PERMISSIONS)
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

# Permisos para que SQS invoque Lambdas
resource "aws_lambda_permission" "allow_sqs_pdf" {
  statement_id  = "AllowExecutionFromSQSPDF"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf_generator.function_name
  principal     = "sqs.amazonaws.com"
  source_arn     = var.pdf_queue_arn
}

resource "aws_lambda_permission" "allow_sqs_notification" {
  statement_id  = "AllowExecutionFromSQSNotification"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification.function_name
  principal     = "sqs.amazonaws.com"
  source_arn     = var.notification_queue_arn
}

# ==========================================
# 6. STEP FUNCTIONS (ORQUESTADOR)
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
        ResultPath = "$.update_inventory_result"
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
        ResultPath = "$.update_reservation_result"
        End = true
      },
      "FinalizarExito" = {
        Type     = "Task"
        Resource = "arn:aws:states:::events:putEvents"
        Parameters = {
          Entries = [
            {
              Detail = {
                "reservationId.$" = "$.reservationId",
                "status"          = "CONFIRMED"
              },
              DetailType = "ticket.confirmed",
              EventBusName = var.event_bus_name,
              Source     = "cloudticket.orchestrator"
            }
          ]
        }
        End = true
      }
    }
  })
}