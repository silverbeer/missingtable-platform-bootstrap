variable "uptimerobot_api_key" {
  description = "UptimeRobot API key (from Integrations > API page)"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "The domain name to monitor"
  type        = string
  default     = "missingtable.com"
}

variable "email_alert_contact_id" {
  description = "UptimeRobot alert contact ID for email notifications (find in dashboard: My Settings > Alert Contacts)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for Secrets Manager"
  type        = string
  default     = "us-east-2"
}
