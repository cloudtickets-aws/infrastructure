# ==========================================
# 1. CAPA DE ALMACENAMIENTO DE OBJETOS (S3)
# ==========================================

# Bucket para Hosting del Frontend (Sitio Estático)
resource "aws_s3_bucket" "frontend_host" {
  bucket = "${var.project_name}-site-${var.environment}"
}

# Configuración de Hosting Estático para el Frontend
resource "aws_s3_bucket_website_configuration" "frontend_config" {
  bucket = aws_s3_bucket.frontend_host.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Bucket para almacenar los tickets generados (PDFs)
resource "aws_s3_bucket" "tickets_storage" {
  bucket = "${var.project_name}-tickets-${var.environment}"
}

# Red de Distribución (CloudFront) para el Frontend
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

# ==========================================
# 2. CAPA DE PERSISTENCIA (DYNAMODB)
# ==========================================

# Tabla de Reservas (Control de estado de la compra)
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
    enabled         = true
  }
}

# Tabla de Inventario (Control de disponibilidad de asientos)
resource "aws_dynamodb_table" "events_inventory" {
  name           = "${var.project_name}-inventory-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "EventID"
  range_key      = "SeatID"

  attribute {
    name = "EventID"
    type = "S"
  }

  attribute {
    name = "SeatID"
    type = "S"
  }
}