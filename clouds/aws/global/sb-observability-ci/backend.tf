terraform {
  # Native S3 locking (OpenTofu >= 1.10), not the DynamoDB table: new stacks
  # start where SB-1709 moves the rest.
  backend "s3" {
    bucket       = "missingtable-terraform-state"
    key          = "aws/global/sb-observability-ci/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}
