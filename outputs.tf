output "app_cloudfront_id" {
  description = "ID de CloudFront para configurar en los Secrets del Frontend"
  value       = module.storage.cloudfront_id
}

output "app_url" {
  description = "URL oficial de CloudTickets"
  value       = "https://${module.storage.website_url}"
}