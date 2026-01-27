output "event_bus_name" {
  description = "Nombre del bus de eventos"
  value       = aws_cloudwatch_event_bus.project_bus.name
}

output "event_bus_arn" {
  description = "ARN del bus de eventos"
  value       = aws_cloudwatch_event_bus.project_bus.arn
}

output "reservation_queue_arn" {
  description = "ARN de la cola SQS de reservas"
  value       = aws_sqs_queue.reservation_queue.arn
}