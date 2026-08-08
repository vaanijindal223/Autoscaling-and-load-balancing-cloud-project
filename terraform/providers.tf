terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment once you create an S3 bucket + DynamoDB table for remote state
  # (do this manually, once, BEFORE running terraform init with this block enabled)
  #
  # backend "s3" {
  #   bucket         = "your-unique-tfstate-bucket-name"
  #   key            = "auto-scaling-project/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AutoScaling-LoadBalancing-Ext"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
