# --- Datos del Frontend ---
output "frontend_url" {
  description = "URL para acceder a la aplicación web"
  value       = module.storage.website_url
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución para hacer despliegues (GitHub Actions)"
  value       = module.storage.cloudfront_id
}

# --- Datos de Seguridad (Para validar) ---
output "ingestion_lambda_role_arn" {
  description = "ARN del rol creado para la Lambda de ingesta"
  value       = module.security.lambda_ingestion_role_arn
}

output "backend_api_url" {
  description = "URL para configurar en el .env de React"
  value       = module.compute.api_url
}