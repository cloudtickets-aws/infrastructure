variable "project_name" {}
variable "environment" {}

# Datos de Seguridad
variable "lambda_ingestion_role_arn" {
  description = "ARN del rol creado en el módulo de seguridad"
}

# Datos de Storage (Nombres de tablas para el código Node.js)
variable "inventory_table_name" {}
variable "reservations_table_name" {}
variable "tickets_bucket_name" {
  description = "Nombre del bucket de S3 para almacenar los PDFs"
  type        = string
}

variable "event_bus_name" {
  description = "Nombre del EventBridge Bus para publicar eventos"
}

variable "event_bus_arn" {
  description = "ARN del EventBridge Bus para la Step Function"
  type        = string
}

variable "reservation_queue_arn" {
  description = "ARN de la cola SQS para permisos de IAM"
  type        = string
}

variable "notification_queue_arn" {
  description = "ARN de la cola SQS para permisos de IAM"
  type        = string
}

variable "pdf_queue_arn" {
  description = "ARN de la cola SQS pdf"
  type = string
}

variable "sfn_role_arn" {
  description = "ARN del rol de IAM para la Step Function"
  type        = string
}

