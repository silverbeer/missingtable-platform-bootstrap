output "monitor_frontend_id" {
  description = "UptimeRobot monitor ID for frontend"
  value       = uptimerobot_monitor.frontend.id
}

output "monitor_api_id" {
  description = "UptimeRobot monitor ID for API"
  value       = uptimerobot_monitor.api.id
}

output "status_page_url" {
  description = "Public status page URL"
  value       = uptimerobot_psp.main.homepage_link
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret for the UptimeRobot API key"
  value       = aws_secretsmanager_secret.uptimerobot_api_key.arn
}
