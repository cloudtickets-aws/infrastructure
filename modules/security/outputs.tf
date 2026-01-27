output "lambda_ingestion_role_arn" {
  description = "ARN del rol de IAM para la lambda de ingesta"
  value       = aws_iam_role.lambda_ingestion_role.arn
}

output "lambda_ingestion_role_name" {
  description = "Nombre del rol de IAM"
  value       = aws_iam_role.lambda_ingestion_role.name
}