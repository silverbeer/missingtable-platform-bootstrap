terraform {
  backend "s3" {
    bucket         = "missingtable-terraform-state"
    key            = "aws/global/quality-site/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
