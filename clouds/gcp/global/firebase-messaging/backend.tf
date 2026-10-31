terraform {
  backend "s3" {
    bucket         = "missingtable-terraform-state"
    key            = "gcp/global/firebase-messaging/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
