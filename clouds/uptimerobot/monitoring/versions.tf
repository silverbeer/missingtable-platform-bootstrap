terraform {
  required_version = ">= 1.6.0"

  required_providers {
    uptimerobot = {
      source  = "uptimerobot/uptimerobot"
      version = "~> 1.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
