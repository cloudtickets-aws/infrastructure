# --- Variables de Contexto ---
variable "project_name" {
  description = "Nombre del proyecto para el naming de los roles"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev/prod)"
  type        = string
}

# --- Variables de Almacenamiento (S3) ---
variable "frontend_bucket_id" {
  description = "ID del bucket de frontend para la política de acceso público"
  type        = string
}

variable "frontend_bucket_arn" {
  description = "ARN del bucket de frontend para la política de permisos"
  type        = string
}

variable "tickets_bucket_arn" {
  description = "ARN del bucket de tickets para que las lambdas puedan escribir"
  type        = string
}

# --- Variables de Persistencia (DynamoDB) ---
variable "reservations_table_arn" {
  description = "ARN de la tabla de reservas para permisos de IAM"
  type        = string
}

variable "inventory_table_arn" {
  description = "ARN de la tabla de inventario para permisos de IAM"
  type        = string
}

variable "reservation_queue_arn" {
  description = "ARN de la cola SQS para permisos de IAM"
  type        = string
}
