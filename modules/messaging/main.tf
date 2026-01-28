# 1. El Bus de Eventos Central
resource "aws_cloudwatch_event_bus" "project_bus" {
  name = "${var.project_name}-bus-${var.environment}"
}

# 2. Cola SQS para Procesamiento de Reservas
resource "aws_sqs_queue" "reservation_queue" {
  name                       = "${var.project_name}-reservation-queue-${var.environment}"
  message_retention_seconds  = 86400 # 1 día
  visibility_timeout_seconds = 60    # Tiempo para que la Lambda procese sin que el mensaje reaparezca
}

# 3. Regla de EventBridge para filtrar eventos
resource "aws_cloudwatch_event_rule" "reservation_requested_rule" {
  name           = "reservation-requested-rule"
  description    = "Captura solicitudes de reserva y las envía a SQS"
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name

  event_pattern = jsonencode({
    "detail-type": ["reservation.requested"]
  })
}

# 4. Target: Conectar la regla con la cola SQS
resource "aws_cloudwatch_event_target" "sqs_target" {
  rule           = aws_cloudwatch_event_rule.reservation_requested_rule.name
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name
  arn            = aws_sqs_queue.reservation_queue.arn
}

# 5. Política de SQS para permitir que EventBridge le escriba
resource "aws_sqs_queue_policy" "allow_eventbridge" {
  queue_url = aws_sqs_queue.reservation_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.reservation_queue.arn
      Condition = {
        ArnEquals = { "aws:SourceArn": aws_cloudwatch_event_rule.reservation_requested_rule.arn }
      }
    }]
  })
}

# ==========================================
# 6. COLAS ADICIONALES (PDF Y NOTIFICACIONES)
# ==========================================

resource "aws_sqs_queue" "pdf_queue" {
  name                       = "${var.project_name}-pdf-queue-${var.environment}"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 120 
}

resource "aws_sqs_queue" "notification_queue" {
  name                       = "${var.project_name}-notification-queue-${var.environment}"
  message_retention_seconds  = 86400
}

# ==========================================
# 7. REGLAS PARA FLUJO DE SALIDA
# ==========================================

# Regla: Ticket Confirmado -> Generar PDF
resource "aws_cloudwatch_event_rule" "ticket_confirmed_rule" {
  name           = "ticket-confirmed-rule"
  description    = "Captura confirmaciones de Step Functions para generar PDF"
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name

  event_pattern = jsonencode({
    "detail-type": ["ticket.confirmed"]
  })
}

# Regla: PDF Generado -> Enviar Notificación
resource "aws_cloudwatch_event_rule" "pdf_generated_rule" {
  name           = "pdf-generated-rule"
  description    = "Captura cuando el PDF está listo para enviar email"
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name

  event_pattern = jsonencode({
    "detail-type": ["pdf.generated"]
  })
}

# ==========================================
# 8. TARGETS PARA FLUJO DE SALIDA
# ==========================================

resource "aws_cloudwatch_event_target" "pdf_target" {
  rule           = aws_cloudwatch_event_rule.ticket_confirmed_rule.name
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name
  arn            = aws_sqs_queue.pdf_queue.arn
}

resource "aws_cloudwatch_event_target" "notification_target" {
  rule           = aws_cloudwatch_event_rule.pdf_generated_rule.name
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name
  arn            = aws_sqs_queue.notification_queue.arn
}