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

resource "aws_s3_bucket" "my_bucket" {
    bucket = "missing-table-open-tofu-learning"
}