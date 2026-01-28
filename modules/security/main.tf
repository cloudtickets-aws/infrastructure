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

resource "aws_iam_policy" "lambda_main_policy" {
  name        = "${var.project_name}-lambda-main-policy-${var.environment}"
  description = "Permisos para DynamoDB, Logs, EventBridge, SQS, Step Functions Control, S3 y SES"

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
        Resource = "*" 
      },
      {
        Sid    = "AllowSQSRead"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = "*" 
      },
      {
        Sid    = "AllowStepFunctionsControl"
        Action = [
          "states:StartExecution",
          "states:SendTaskSuccess",
          "states:SendTaskFailure"
        ]
        Effect   = "Allow"
        Resource = "*" 
      },
      {
        Sid      = "AllowS3TicketWrite"
        Action   = ["s3:PutObject", "s3:PutObjectAcl", "s3:GetObject"]
        Effect   = "Allow"
        Resource = "${var.tickets_bucket_arn}/*"
      },
      {
        Sid      = "AllowSESEmail"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_main" {
  role       = aws_iam_role.lambda_ingestion_role.name
  policy_arn = aws_iam_policy.lambda_main_policy.arn
}

# ==========================================
# 3. ROLES Y POLÍTICAS PARA STEP FUNCTIONS
# ==========================================

resource "aws_iam_role" "sfn_role" {
  name = "${var.project_name}-sfn-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "sfn_main_policy" {
  name        = "${var.project_name}-sfn-main-policy-${var.environment}"
  description = "Permite a la Step Function interactuar con DynamoDB, EventBridge y Lambdas"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDynamoDirectAction"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Effect   = "Allow"
        Resource = [
          var.reservations_table_arn,
          var.inventory_table_arn
        ]
      },
      {
        Sid    = "AllowSFNLogging"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid      = "AllowSFNToEventBridge"
        Action   = "events:PutEvents"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Sid      = "AllowSFNInvokeLambda"
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "*" # Permite invocar save_token y verificarStatus si fuera necesario
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_sfn_main" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_main_policy.arn
}