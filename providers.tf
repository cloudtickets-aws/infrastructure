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

