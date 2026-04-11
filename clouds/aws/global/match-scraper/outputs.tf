output "s3_bucket_name" {
  description = "S3 bucket name for agent state"
  value       = aws_s3_bucket.agent_state.id
}

output "journal_s3_key" {
  description = "S3 key for the run journal"
  value       = local.journal_key
}

output "iam_user_name" {
  description = "IAM user name for the agent"
  value       = aws_iam_user.agent.name
}

output "aws_access_key_id" {
  description = "AWS access key ID for the agent (add to K8s secret)"
  value       = aws_iam_access_key.agent.id
}

output "aws_secret_access_key" {
  description = "AWS secret access key for the agent (add to K8s secret)"
  value       = aws_iam_access_key.agent.secret
  sensitive   = true
}
