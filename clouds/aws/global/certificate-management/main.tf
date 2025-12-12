locals {
  common_tags = {
    project     = "missing-table"
    environment = "global"
    managed_by  = "terraform"
    cost_center = "engineering"
  }
}

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(local.common_tags, {
    name    = "${var.domain_name}-zone"
    purpose = "DNS for ${var.domain_name}"
  })
}

resource "aws_secretsmanager_secret" "tls-cert" {
  name        = "${var.domain_name}-tls"
  description = "TLS certificate for ${var.domain_name}"

  tags = merge(local.common_tags, {
    name = "${var.domain_name}-tls"
  })
}

# =============================================================================
# GRAFANA CLOUD CREDENTIALS - for Kubernetes monitoring
# =============================================================================

resource "aws_secretsmanager_secret" "grafana_cloud" {
  name        = "grafana-cloud-credentials"
  description = "Grafana Cloud API credentials for Kubernetes monitoring"

  tags = merge(local.common_tags, {
    name    = "grafana-cloud-credentials"
    purpose = "Observability for DOKS cluster"
  })
}

resource "aws_iam_user" "external_secrets" {
  name = "external-secrets-${var.domain_name}"

  tags = merge(local.common_tags, {
    name    = "external-secrets-${var.domain_name}"
    purpose = "External Secrets for ${var.domain_name}"
  })
}

resource "aws_iam_user_policy" "external_secrets" {
  name = "secrets-manager-read-only-${var.domain_name}"
  user = aws_iam_user.external_secrets.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "secretsmanager:GetSecretValue"
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret.tls-cert.arn,
          aws_secretsmanager_secret.qualityplaybook_tls.arn,
          aws_secretsmanager_secret.grafana_cloud.arn
        ]
      }
    ]
  })
}

resource "aws_iam_access_key" "external_secrets" {
  user = aws_iam_user.external_secrets.name
}

resource "aws_iam_role" "certbot_lambda" {
  name = "certbot_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    name = "certbot-lambda-role"
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.certbot_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_route53" {
  role = aws_iam_role.certbot_lambda.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetHostedZone",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          aws_route53_zone.main.arn,
          aws_route53_zone.qualityplaybook.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "secrets-manager-write"
  role = aws_iam_role.certbot_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "secretsmanager:PutSecretValue"
        Resource = [
          aws_secretsmanager_secret.tls-cert.arn,
          aws_secretsmanager_secret.qualityplaybook_tls.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_acm" {
  name = "acm-import"
  role = aws_iam_role.certbot_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm:ImportCertificate",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "acm:AddTagsToCertificate",
          "acm:RemoveTagsFromCertificate",
          "acm:ListTagsForCertificate"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "certbot" {
  function_name = "certbot-renewal"
  role          = aws_iam_role.certbot_lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.certbot_lambda.repository_url}:latest"
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      DOMAIN_NAME       = var.domain_name
      LETSENCRYPT_EMAIL = var.letsencrypt_email
      SECRET_ID         = aws_secretsmanager_secret.tls-cert.id
      HOSTED_ZONE_ID    = aws_route53_zone.main.zone_id
    }
  }

  tags = merge(local.common_tags, {
    name = "certbot-renewal-${var.domain_name}"
  })
}

resource "aws_cloudwatch_event_rule" "certbot_renewal" {
  name                = "certbot-renewal-${var.domain_name}"
  description         = "Schedule certbot renewal for ${var.domain_name}"
  schedule_expression = "cron(0 0 * * ? *)"

  tags = merge(local.common_tags, {
    name = "certbot-renewal-${var.domain_name}"
  })
}

resource "aws_cloudwatch_event_target" "certbot_renewal" {
  rule = aws_cloudwatch_event_rule.certbot_renewal.name
  arn  = aws_lambda_function.certbot.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# ECR repository for certbot Lambda
resource "aws_ecr_repository" "certbot_lambda" {
  name                 = "certbot-lambda"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = merge(local.common_tags, {
    name = "certbot-lambda"
  })
}

# =============================================================================
# QUALITYPLAYBOOK.DEV - Additional domain
# =============================================================================

resource "aws_route53_zone" "qualityplaybook" {
  name = "qualityplaybook.dev"

  tags = merge(local.common_tags, {
    name    = "qualityplaybook.dev-zone"
    purpose = "DNS for qualityplaybook.dev"
  })
}

resource "aws_secretsmanager_secret" "qualityplaybook_tls" {
  name        = "qualityplaybook.dev-tls"
  description = "TLS certificate for qualityplaybook.dev"

  tags = merge(local.common_tags, {
    name = "qualityplaybook.dev-tls"
  })
}

# Lambda for qualityplaybook.dev certificate renewal
resource "aws_lambda_function" "certbot_qualityplaybook" {
  function_name = "certbot-renewal-qualityplaybook"
  role          = aws_iam_role.certbot_lambda.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.certbot_lambda.repository_url}:latest"
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      DOMAIN_NAME       = "qualityplaybook.dev"
      LETSENCRYPT_EMAIL = var.letsencrypt_email
      SECRET_ID         = aws_secretsmanager_secret.qualityplaybook_tls.id
      HOSTED_ZONE_ID    = aws_route53_zone.qualityplaybook.zone_id
    }
  }

  tags = merge(local.common_tags, {
    name = "certbot-renewal-qualityplaybook"
  })
}

# EventBridge schedule for qualityplaybook.dev
resource "aws_cloudwatch_event_rule" "certbot_renewal_qualityplaybook" {
  name                = "certbot-renewal-qualityplaybook"
  description         = "Schedule certbot renewal for qualityplaybook.dev"
  schedule_expression = "cron(0 0 * * ? *)"

  tags = merge(local.common_tags, {
    name = "certbot-renewal-qualityplaybook"
  })
}

resource "aws_cloudwatch_event_target" "certbot_renewal_qualityplaybook" {
  rule = aws_cloudwatch_event_rule.certbot_renewal_qualityplaybook.name
  arn  = aws_lambda_function.certbot_qualityplaybook.arn
}

resource "aws_lambda_permission" "eventbridge_qualityplaybook" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.certbot_qualityplaybook.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.certbot_renewal_qualityplaybook.arn
}

# DNS A record for qualityplaybook.dev pointing to DOKS ingress
resource "aws_route53_record" "qualityplaybook_root" {
  zone_id = aws_route53_zone.qualityplaybook.zone_id
  name    = "qualityplaybook.dev"
  type    = "A"
  ttl     = 300
  records = ["137.184.242.213"]
}

resource "aws_route53_record" "qualityplaybook_www" {
  zone_id = aws_route53_zone.qualityplaybook.zone_id
  name    = "www.qualityplaybook.dev"
  type    = "A"
  ttl     = 300
  records = ["137.184.242.213"]
}

# =============================================================================
# MISSINGTABLE.COM - DNS A Records
# =============================================================================

# DNS A record for missingtable.com pointing to DOKS ingress
resource "aws_route53_record" "missingtable_root" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = ["137.184.242.213"]
}

resource "aws_route53_record" "missingtable_www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = ["137.184.242.213"]
}
