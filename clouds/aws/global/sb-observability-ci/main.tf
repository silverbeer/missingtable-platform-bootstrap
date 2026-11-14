# =============================================================================
# GitHub Actions role for silverbeer/sb-observability (SB-1707)
# =============================================================================
# The repo's tofu workflow needs only its own state: read, write and lock
# objects under sb-observability/ in the shared state bucket. Locking is native
# S3 (a .tflock object next to the state), so no DynamoDB permission.
#
# Reuses the GitHub OIDC provider created by the quality-site stack — an AWS
# account can hold only one provider per URL.

locals {
  common_tags = {
    project     = "sb-observability"
    environment = "global"
    managed_by  = "terraform"
    cost_center = "engineering"
  }

  github_repo = "silverbeer/sb-observability"
  # GitHub issues repos created since its immutable-subject change an OIDC
  # `sub` that carries owner and repo IDs, not just names:
  #   repo:silverbeer@96834016/sb-observability@1457964178:<ref>
  # Read it with: gh api repos/silverbeer/sb-observability/actions/oidc/customization/sub
  # The IDs also mean a rename or a recreated repo of the same name no longer matches.
  github_sub_prefix = "repo:silverbeer@96834016/sb-observability@1457964178"
  state_bucket      = "missingtable-terraform-state"
  state_prefix      = "sb-observability/"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions_sb_observability" {
  name        = "github-actions-sb-observability"
  description = "Assumed by GitHub Actions in ${local.github_repo} for OpenTofu state"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Any branch or PR: PRs plan, pushes to main apply.
            "token.actions.githubusercontent.com:sub" = "${local.github_sub_prefix}:*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    name = "github-actions-sb-observability"
  })
}

resource "aws_iam_role_policy" "github_actions_sb_observability" {
  name = "tofu-state"
  role = aws_iam_role.github_actions_sb_observability.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListOwnPrefix"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${local.state_bucket}"
        Condition = {
          StringLike = { "s3:prefix" = ["${local.state_prefix}*"] }
        }
      },
      {
        Sid      = "StateAndLockObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${local.state_bucket}/${local.state_prefix}*"
      }
    ]
  })
}
