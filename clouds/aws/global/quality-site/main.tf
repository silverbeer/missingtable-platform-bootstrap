 locals {
  common_tags = {
    project     = "missingtable"
    environment = "production"
    managed_by  = "terraform"
    cost_center = "quality"
  }
}

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

resource "aws_cloudfront_origin_access_control" "quality_site_cdn_oac" {
    name                              = "quality-site-oac"
    description                       = "OAC for quality.missingtable.com"
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "quality_site_policy" {
    bucket = aws_s3_bucket.quality_site.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "AllowCloudFrontServicePrincipal"
                Effect = "Allow"
                Principal = {
                    Service = "cloudfront.amazonaws.com"
                }
                Action = "s3:GetObject"
                Resource = "${aws_s3_bucket.quality_site.arn}/*"
                Condition = {
                    StringEquals = {
                        "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
                    }
                }
            }
        ]
    })
}

resource "aws_acm_certificate" "quality_site_cert" {
    provider          = aws.us_east_1
    domain_name       = "quality.missingtable.com"
    validation_method  = "DNS"

    tags = merge(local.common_tags, {
        name = "quality-missingtable-com-cert"
    })

    lifecycle {
        create_before_destroy = true
    }
}

data "aws_route53_zone" "missingtable" {
    name = "missingtable.com"
}

resource "aws_route53_record" "quality_site_cert_validation" {
    for_each = {
        for dvo in aws_acm_certificate.quality_site_cert.domain_validation_options : dvo.domain_name => {
            name = dvo.resource_record_name
            record = dvo.resource_record_value
            type = dvo.resource_record_type
        }
    }

    zone_id         = data.aws_route53_zone.missingtable.zone_id
    name            = each.value.name
    type            = each.value.type
    ttl             = 60
    records         = [each.value.record]
    allow_overwrite = true
}