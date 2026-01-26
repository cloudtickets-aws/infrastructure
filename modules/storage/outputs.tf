# El ID de la distribución para que GitHub Actions sepa qué invalidar
output "cloudfront_id" {
  description = "ID de la distribución de CloudFront"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

# El dominio (URL) para que puedas entrar a ver tu página
output "website_url" {
  description = "URL de la aplicación en CloudFront"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

# El nombre del bucket (por si lo necesitas confirmar)
output "s3_bucket_name" {
  description = "Nombre del bucket de hosting"
  value       = aws_s3_bucket.frontend_host.id
}