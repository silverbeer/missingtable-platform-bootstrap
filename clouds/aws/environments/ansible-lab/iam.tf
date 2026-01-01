# =============================================================================
# IAM ROLE AND POLICIES - For RADIUS server EC2 instance
# =============================================================================

# IAM Role for the RADIUS server to access S3 bucket
resource "aws_iam_role" "radius_server_role" {
  name = "ansible-lab-radius-server-role"

  # Allow EC2 instances to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    name = "ansible-lab-radius-server-role"
  })
}

# Attach S3 read-only policy to the role
resource "aws_iam_role_policy" "radius_server_s3_access" {
  name = "ansible-lab-radius-server-s3-access"
  role = aws_iam_role.radius_server_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.radius_server_config.arn,
          "${aws_s3_bucket.radius_server_config.arn}/*"
        ]
      }
    ]
  })
}

# Create instance profile to attach the role to EC2
resource "aws_iam_instance_profile" "radius_server" {
  name = "ansible-lab-radius-server-profile"
  role = aws_iam_role.radius_server_role.name

  tags = merge(local.common_tags, {
    name = "ansible-lab-radius-server-profile"
  })
}



