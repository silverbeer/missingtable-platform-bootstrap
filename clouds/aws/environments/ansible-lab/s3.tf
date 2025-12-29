# =============================================================================
# S3 BUCKET - For RADIUS server config/health checks
# =============================================================================

resource "aws_s3_bucket" "radius_server_config" {
  bucket = "ansible-lab-radius-config-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    name = "ansible-lab-radius-config"
  })
}

# Random suffix to ensure bucket name is globally unique
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Block public access (security best practice)
resource "aws_s3_bucket_public_access_block" "radius_server_config" {
  bucket = aws_s3_bucket.radius_server_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create the health-check marker file
resource "aws_s3_object" "health_check_marker" {
  bucket  = aws_s3_bucket.radius_server_config.id
  key     = "health-check/marker.txt"
  content = "OK - ${timestamp()}"

  tags = merge(local.common_tags, {
    name = "health-check-marker"
  })
}
