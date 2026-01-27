# URL base de la API para conectar con el Frontend
output "api_url" {
  description = "URL del endpoint de la API Gateway para el cliente"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

# ARN de la Lambda por si necesitamos monitorearla
output "ingestion_lambda_arn" {
  description = "ARN de la función Lambda de ingesta"
  value       = aws_lambda_function.ingestion.arn
}

# Nombre de la función para logs
output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.ingestion.function_name
}