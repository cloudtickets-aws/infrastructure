# ==========================================
# 1. OUTPUTS DE ALMACENAMIENTO DE OBJETOS (S3)
# ==========================================

# Datos del Bucket de Frontend (Hosting)
output "frontend_bucket_id" {
  description = "ID del bucket para el hosting (Nombre)"
  value       = aws_s3_bucket.frontend_host.id
}

output "frontend_bucket_arn" {
  description = "ARN del bucket para políticas de seguridad"
  value       = aws_s3_bucket.frontend_host.arn
}

# Datos del Bucket de Tickets (PDFs)
output "tickets_bucket_id" {
  description = "ID del bucket de tickets (Nombre)"
  value       = aws_s3_bucket.tickets_storage.id
}

output "tickets_bucket_name" {
  description = "Nombre del bucket donde se guardan los tickets"
  value       = aws_s3_bucket.tickets_storage.id
}

output "tickets_bucket_arn" {
  description = "ARN del bucket de tickets para permisos de escritura"
  value       = aws_s3_bucket.tickets_storage.arn
}

# Datos de la Distribución (CloudFront)
output "cloudfront_id" {
  description = "ID de la distribución para invalidaciones de cache"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "website_url" {
  description = "URL pública de la aplicación"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

# ==========================================
# 2. OUTPUTS DE PERSISTENCIA (DYNAMODB)
# ==========================================

# Datos de la Tabla de Reservas
output "reservations_table_name" {
  description = "Nombre de la tabla de reservas"
  value       = aws_dynamodb_table.reservations.name
}

output "reservations_table_arn" {
  description = "ARN de la tabla de reservas para IAM"
  value       = aws_dynamodb_table.reservations.arn
}

# Datos de la Tabla de Inventario
output "inventory_table_name" {
  description = "Nombre de la tabla de inventario"
  value       = aws_dynamodb_table.events_inventory.name
}

output "inventory_table_arn" {
  description = "ARN de la tabla de inventario para IAM"
  value       = aws_dynamodb_table.events_inventory.arn
}