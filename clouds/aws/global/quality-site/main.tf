# =============================================================================
# COMMON
# =============================================================================

locals {
  common_tags = {
    project     = "missingtable"
    environment = "production"
    managed_by  = "terraform"
    cost_center = "quality"
  }
}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "missingtable" {
  name = "missingtable.com"
}

# =============================================================================
# S3 BUCKET - Static site storage (private, CloudFront access only)
# =============================================================================

resource "aws_s3_bucket" "quality_site" {
  bucket = "quality-missingtable-com"

  tags = merge(local.common_tags, {
    name = "quality-missingtable-com"
  })
}

resource "aws_s3_bucket_public_access_block" "quality_site_public_block" {
  bucket = aws_s3_bucket.quality_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "quality_site_policy" {
  bucket = aws_s3_bucket.quality_site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.quality_site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
            "AWS:SourceArn"     = aws_cloudfront_distribution.quality_site_cdn.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "quality_site_lifecycle" {
    bucket = aws_s3_bucket.quality_site.id

    rule {
        id = "delete-old-runs"
        status = "Enabled"

        filter {
            prefix = "runs/"        
        }

        expiration {
            days = 30
        }
    }
}

# NOTE: index.html is managed by the quality.yml workflow, not Terraform.
# The workflow generates the dashboard and uploads it to S3.
# Do NOT add an aws_s3_object for index.html here.


# =============================================================================
# ACM CERTIFICATE - HTTPS for CloudFront (must be in us-east-1)
# =============================================================================

resource "aws_acm_certificate" "quality_site_cert" {
  provider          = aws.us_east_1
  domain_name       = "quality.missingtable.com"
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    name = "quality-missingtable-com-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "quality_site_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.quality_site_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.missingtable.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "quality_site_cert_validation" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.quality_site_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.quality_site_cert_validation : record.fqdn]
}

# =============================================================================
# CLOUDFRONT - CDN and HTTPS termination
# =============================================================================

# CloudFront Function to handle subdirectory index.html requests
# Without this, paths like /foo/bar/ return 403 instead of /foo/bar/index.html
resource "aws_cloudfront_function" "index_rewrite" {
  name    = "quality-site-index-rewrite"
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "Rewrite directory paths to index.html"

  code = <<-EOF
    function handler(event) {
      var request = event.request;
      var uri = request.uri;

      // If URI ends with '/', append index.html
      if (uri.endsWith('/')) {
        request.uri += 'index.html';
      }
      // If URI doesn't have an extension, assume it's a directory and add /index.html
      else if (!uri.includes('.')) {
        request.uri += '/index.html';
      }

      return request;
    }
  EOF
}

resource "aws_cloudfront_origin_access_control" "quality_site_cdn_oac" {
  name                              = "quality-site-oac"
  description                       = "OAC for quality.missingtable.com"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "quality_site_cdn" {
    enabled             = true
    is_ipv6_enabled     = true
    default_root_object = "index.html"
    aliases             = ["quality.missingtable.com"]

    origin {
        domain_name              = aws_s3_bucket.quality_site.bucket_regional_domain_name
        origin_id                = "S3-quality-site"
        origin_access_control_id = aws_cloudfront_origin_access_control.quality_site_cdn_oac.id
    }

    default_cache_behavior {
        allowed_methods        = ["GET", "HEAD"]
        cached_methods         = ["GET", "HEAD"]
        target_origin_id       = "S3-quality-site"
        viewer_protocol_policy = "redirect-to-https"

        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }

        min_ttl     = 0
        default_ttl = 3600
        max_ttl     = 86400

        function_association {
            event_type   = "viewer-request"
            function_arn = aws_cloudfront_function.index_rewrite.arn
        }
    }

    viewer_certificate {
        acm_certificate_arn      = aws_acm_certificate_validation.quality_site_cert_validation.certificate_arn
        ssl_support_method       = "sni-only"
        minimum_protocol_version = "TLSv1.2_2021"
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    tags = merge(local.common_tags, {
        name = "quality_site_cdn"
    })
}

resource "aws_route53_record" "quality_site_dns" {
    zone_id = data.aws_route53_zone.missingtable.zone_id
    name    = "quality.missingtable.com"
    type    = "A"

    alias {
        name                   = aws_cloudfront_distribution.quality_site_cdn.domain_name
        zone_id                = aws_cloudfront_distribution.quality_site_cdn.hosted_zone_id
        evaluate_target_health = false
    }
}

# =============================================================================
# GITHUB RUNNER - EC2 instance for self-hosted Actions runner
# Cost: ~$15/mo when running. Use runner_enabled=false to destroy.
# =============================================================================
resource "aws_vpc" "runner" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    name = "quality-site-runner-vpc"
  })
}

resource "aws_internet_gateway" "runner" {
  vpc_id = aws_vpc.runner.id

  tags = merge(local.common_tags, {
    name = "quality-site-runner-igw"
  })
}

resource "aws_subnet" "runner" {
  vpc_id                  = aws_vpc.runner.id
  cidr_block              = "10.100.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    name = "quality-site-runner-subnet"
  })
}
 
resource "aws_route_table" "runner" {
  vpc_id = aws_vpc.runner.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.runner.id
  }

  tags = merge(local.common_tags, {
    name = "quality-site-runner-rt"
  })
}

resource "aws_route_table_association" "runner" {
  subnet_id      = aws_subnet.runner.id
  route_table_id = aws_route_table.runner.id
}

resource "aws_security_group" "runner" {
  name        = "quality-site-runner-sg"
  description = "Security group for GitHub Actions runner"
  vpc_id      = aws_vpc.runner.id

  # Note: No inbound rule for GitHub. Runners make outbound connections to GitHub
  # and poll for jobs. GitHub never connects inbound to your runner.
  ingress {
    description = "SSH from allowed IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "Allow all outbound (required for runner to connect to GitHub)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    name = "quality-site-runner-sg"
  })
}

resource "aws_secretsmanager_secret" "runner_token" {
  name        = "quality-site/github-runner-token"
  description = "GitHub Actions runner registration token for missing-table repo"

  tags = merge(local.common_tags, {
    name = "quality-site-runner-token"
  })
}

resource "aws_iam_role" "runner" {
  name = "quality-site-runner-role"

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
    name = "quality-site-runner-role"
  })
}


resource "aws_iam_role_policy" "runner" {
  name = "quality-site-runner-policy"
  role = aws_iam_role.runner.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3WriteAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.quality_site.arn,
          "${aws_s3_bucket.quality_site.arn}/*"
        ]
      },
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = aws_cloudfront_distribution.quality_site_cdn.arn
      },
      {
        Sid    = "SecretsManagerReadToken"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.runner_token.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "runner" {
  name = "quality-site-runner-profile"
  role = aws_iam_role.runner.name

  tags = merge(local.common_tags, {
    name = "quality-site-runner-profile"
  })
}


resource "aws_key_pair" "runner" {
  key_name   = "quality-site-runner-key"
  public_key = var.runner_ssh_public_key

  tags = merge(local.common_tags, {
    name = "quality-site-runner-key"
  })
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "runner" {
  count = var.runner_enabled ? 1 : 0

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.runner.key_name
  vpc_security_group_ids      = [aws_security_group.runner.id]
  subnet_id                   = aws_subnet.runner.id
  iam_instance_profile        = aws_iam_instance_profile.runner.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    name = "quality-site-runner"
    role = "github-runner"
  })
}