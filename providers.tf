terraform {
  required_version = ">= 1.5.0"

  
  backend "s3" {
    bucket  = "cloudtickets-terraform-state" 
    key     = "dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28" 
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project   = "CloudTickets"
      ManagedBy = "Terraform"
      Owner     = "Oscar"
    }
  }
}

# Provider específico para el WAF (Requerido por CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "CloudTickets"
      ManagedBy = "Terraform"
      Owner     = "Oscar"
      Layer     = "Edge-Security"
    }
  }
}
