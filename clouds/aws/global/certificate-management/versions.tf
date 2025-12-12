terraform {
  backend "s3" {
    bucket         = "missingtable-terraform-state"
    key            = "aws/global/certificate-management/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }

  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}