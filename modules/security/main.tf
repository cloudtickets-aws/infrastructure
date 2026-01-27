# ==========================================
# 1. POLÍTICAS DE ACCESO PARA STORAGE (S3)
# ==========================================

resource "aws_s3_bucket_public_access_block" "frontend_access" {
  bucket = var.frontend_bucket_id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = var.frontend_bucket_id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${var.frontend_bucket_arn}/*"
      },
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.frontend_access]
}

# ==========================================
# 2. ROLES Y POLÍTICAS DE CÓMPUTO (LAMBDAS)
# ==========================================

resource "aws_iam_role" "lambda_ingestion_role" {
  name = "${var.project_name}-lambda-ingestion-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Política de permisos para DynamoDB, CloudWatch Logs y EventBridge
resource "aws_iam_policy" "lambda_main_policy" {
  name        = "${var.project_name}-lambda-main-policy-${var.environment}"
  description = "Permite interactuar con DynamoDB, Logs y publicar en EventBridge"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDynamoAccess"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = [
          var.reservations_table_arn,
          var.inventory_table_arn
        ]
      },
      {
        Sid    = "AllowLogging"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "AllowEventBridgePublish"
        Action = [
          "events:PutEvents"
        ]
        Effect   = "Allow"
        Resource = "*" # En producción se limita al ARN del Bus, por ahora "*" para facilitar el despliegue inicial
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_main" {
  role       = aws_iam_role.lambda_ingestion_role.name
  policy_arn = aws_iam_policy.lambda_main_policy.arn
}