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