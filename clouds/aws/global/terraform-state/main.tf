# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "missingtable-terraform-state"

  tags = {
    name        = "terraform-state"
    project     = "missing-table"
    environment = "global"
    managed_by  = "terraform"
    cost_center = "engineering"
  }
}

# Enable versioning (recover from mistakes)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for Terraform State Locking
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    name        = "terraform-state-lock"
    project     = "missing-table"
    environment = "global"
    managed_by  = "terraform"
    cost_center = "engineering"
  }
}