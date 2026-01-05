output "runner_public_ip" {
  description = "Public IP of the EC2 runner (if enabled)"
  value       = var.runner_enabled ? aws_instance.runner[0].public_ip : null
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions_quality.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}