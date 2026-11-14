output "role_arn" {
  description = "Set as the AWS_OIDC_ROLE_ARN secret on silverbeer/sb-observability"
  value       = aws_iam_role.github_actions_sb_observability.arn
}
