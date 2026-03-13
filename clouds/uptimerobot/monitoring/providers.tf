provider "uptimerobot" {
  api_key = var.uptimerobot_api_key
}

provider "aws" {
  region = var.aws_region
}
