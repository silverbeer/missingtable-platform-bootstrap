locals {
  common_tags = {
    project     = "missing-table"
    environment = "global"
    managed_by  = "terraform"
    cost_center = "engineering"
  }

  journal_key = "journal/latest.json"
}

# =============================================================================
# S3 BUCKET — agent state (journal.json cross-run memory)
# =============================================================================

resource "aws_s3_bucket" "agent_state" {
  bucket = "missingtable-match-scraper"

  tags = merge(local.common_tags, {
    name = "missingtable-match-scraper"
  })
}

resource "aws_s3_bucket_public_access_block" "agent_state" {
  bucket = aws_s3_bucket.agent_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "agent_state" {
  bucket = aws_s3_bucket.agent_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# =============================================================================
# IAM USER — least-privilege access for match-scraper-agent pod
# =============================================================================

resource "aws_iam_user" "agent" {
  name = "match-scraper-agent"

  tags = merge(local.common_tags, {
    name = "match-scraper-agent"
  })
}

resource "aws_iam_user_policy" "agent_journal" {
  name = "match-scraper-agent-journal"
  user = aws_iam_user.agent.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "JournalReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = "${aws_s3_bucket.agent_state.arn}/${local.journal_key}"
      }
    ]
  })
}

resource "aws_iam_access_key" "agent" {
  user = aws_iam_user.agent.name
}
