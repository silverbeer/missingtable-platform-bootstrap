terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

module "vpc" {
  source = "../../../../modules/aws/vpc"
  vpc_name = "missing-table-vpc"
  vpc_cidr_block = "10.0.0.0/16"
  vpc_availability_zones = ["us-east-2a", "us-east-2b"]
  environment = "dev"
}