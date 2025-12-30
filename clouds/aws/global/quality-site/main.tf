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

resource "aws_s3_object" "index_html" {
    bucket       = aws_s3_bucket.quality_site.id
    key          = "index.html"
    content_type = "text/html"

    content = <<-EOF
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Quality Site - MissingTable</title>
        <style>
            body { font-family: system-ui, sans-serif; max-width: 600px; margin: 100px auto; padding: 20px; text-align: center; }
            h1 { color: #333; }
            p { color: #666; }
            .status { background: #e8f5e9; padding: 10px; border-radius: 4px; margin: 20px 0; }
        </style>
        </head>
        <body>
        <h1>Quality Site for MissingTable</h1>
        <p>Test results and coverage reports for MissingTable</p>
        <div class="status">Coming Soon</div>
        <p><small>Infrastructure deployed via OpenTofu</small></p>
        </body>
        </html>
    EOF
}


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
