# ==============================================================================
# 1. BUS DE EVENTOS CENTRAL
# ==============================================================================
resource "aws_cloudwatch_event_bus" "project_bus" {
  name = "${var.project_name}-bus-${var.environment}"
}

# ==============================================================================
# 2. COLAS SQS (INFRAESTRUCTURA DE TRANSPORTE)
# ==============================================================================

# Cola 1: Procesamiento de Reservas (Ingestión)
resource "aws_sqs_queue" "reservation_queue" {
  name                       = "${var.project_name}-reservation-queue-${var.environment}"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 60
}

# Cola 2: Generación de PDF's
resource "aws_sqs_queue" "pdf_queue" {
  name                       = "${var.project_name}-pdf-queue-${var.environment}"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 120 
}

# Cola 3: Notificaciones (Email/SES)
resource "aws_sqs_queue" "notification_queue" {
  name                       = "${var.project_name}-notification-queue-${var.environment}"
  message_retention_seconds  = 86400
}

# ==============================================================================
# 3. REGLAS DE EVENTBRIDGE (FILTROS DE EVENTOS)
# ==============================================================================

# Regla: Solicitud de Reserva -> Inicia el flujo
resource "aws_cloudwatch_event_rule" "reservation_requested_rule" {
  name           = "reservation-requested-rule"
  description    = "Captura solicitudes de reserva y las envía a SQS"
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name

  event_pattern = jsonencode({
    "detail-type": ["reservation.requested"]
  })
}

# Regla: Ticket Confirmado -> Dispara generación de PDF
resource "aws_cloudwatch_event_rule" "ticket_confirmed_rule" {
  name           = "ticket-confirmed-rule"
  description    = "Captura confirmaciones de Step Functions para generar PDF"
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name

  event_pattern = jsonencode({
    "detail-type": ["ticket.confirmed"]
  })
}

# Regla: PDF Generado -> Dispara envío de notificación
resource "aws_cloudwatch_event_rule" "pdf_generated_rule" {
  name           = "pdf-generated-rule"
  description    = "Captura cuando el PDF está listo para enviar email"
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name

  event_pattern = jsonencode({
    "detail-type": ["pdf.generated"]
  })
}

# ==============================================================================
# 4. POLÍTICAS DE ACCESO SQS (PERMISOS PARA EVENTBRIDGE)
# ==============================================================================

# Política para la cola de Reservas (Ingestión)
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

# Política para la cola de PDF
resource "aws_sqs_queue_policy" "allow_eventbridge_pdf" {
  queue_url = aws_sqs_queue.pdf_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.pdf_queue.arn
      Condition = {
        ArnEquals = { "aws:SourceArn": aws_cloudwatch_event_rule.ticket_confirmed_rule.arn }
      }
    }]
  })
}

# Política para la cola de Notificaciones
resource "aws_sqs_queue_policy" "allow_eventbridge_notifications" {
  queue_url = aws_sqs_queue.notification_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notification_queue.arn
      Condition = {
        ArnEquals = { "aws:SourceArn": aws_cloudwatch_event_rule.pdf_generated_rule.arn }
      }
    }]
  })
}

# ==============================================================================
# 5. TARGETS (CONEXIÓN REGLA -> COLA)
# ==============================================================================

resource "aws_cloudwatch_event_target" "sqs_target" {
  rule           = aws_cloudwatch_event_rule.reservation_requested_rule.name
  event_bus_name = aws_cloudwatch_event_bus.project_bus.name
  arn            = aws_sqs_queue.reservation_queue.arn
}

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