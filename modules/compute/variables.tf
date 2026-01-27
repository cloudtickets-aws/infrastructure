variable "project_name" {}
variable "environment" {}

# Datos de Seguridad
variable "lambda_ingestion_role_arn" {
  description = "ARN del rol creado en el módulo de seguridad"
}

# Datos de Storage (Nombres de tablas para el código Node.js)
variable "inventory_table_name" {}
variable "reservations_table_name" {}

variable "event_bus_name" {
  description = "Nombre del EventBridge Bus para publicar eventos"
}

variable "reservation_queue_arn" {
  description = "ARN de la cola SQS para permisos de IAM"
  type        = string
}

variable "sfn_role_arn" {
  description = "ARN del rol de IAM para la Step Function"
  type        = string
}