resource "aws_dynamodb_table" "reservations" {
  name           = "${var.project_name}-reservations-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ReservationID"

  attribute {
    name = "ReservationID"
    type = "S"
  }

  ttl {
    attribute_name = "ExpirationTime"
    enabled        = true
  }
}

resource "aws_s3_bucket" "frontend_host" {
  bucket = "${var.project_name}-site-${var.environment}"
}

# 1. Habilitar Hosting Estático en el Bucket
resource "aws_s3_bucket_website_configuration" "frontend_config" {
  bucket = aws_s3_bucket.frontend_host.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html" # Clave para que React Router funcione bien
  }
}

# 2. Configurar el acceso público (Necesario para que CloudFront lea los archivos)
resource "aws_s3_bucket_public_access_block" "frontend_access" {
  bucket = aws_s3_bucket.frontend_host.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_host.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_host.arn}/*"
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.frontend_access]
}

# 3. Creación de CloudFront (La CDN)
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.frontend_host.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend_host.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend_host.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}