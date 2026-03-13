locals {
  common_tags = {
    project     = "missing-table"
    environment = "global"
    managed_by  = "terraform"
    cost_center = "engineering"
  }
}

# -----------------------------------------------------------------------------
# Secrets Manager - store API key for reference/backup
# Populate manually: aws secretsmanager put-secret-value \
#   --secret-id uptimerobot-api-key \
#   --secret-string "YOUR_KEY" \
#   --region us-east-2
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "uptimerobot_api_key" {
  name        = "uptimerobot-api-key"
  description = "UptimeRobot API key for monitoring configuration"

  tags = merge(local.common_tags, {
    name = "uptimerobot-api-key"
  })
}

# -----------------------------------------------------------------------------
# Monitors
#
# The email alert contact is created automatically when you sign up for
# UptimeRobot. Find its ID in the dashboard under My Settings > Alert Contacts,
# then pass it as var.email_alert_contact_id.
# -----------------------------------------------------------------------------

resource "uptimerobot_monitor" "frontend" {
  name     = var.domain_name
  url      = "https://${var.domain_name}"
  type     = "HTTP"
  interval = 300

  assigned_alert_contacts = [{
    alert_contact_id = var.email_alert_contact_id
    threshold        = 0
    recurrence       = 0
  }]
}

resource "uptimerobot_monitor" "api" {
  name     = "${var.domain_name} API"
  url      = "https://api.${var.domain_name}/health"
  type     = "HTTP"
  interval = 300

  assigned_alert_contacts = [{
    alert_contact_id = var.email_alert_contact_id
    threshold        = 0
    recurrence       = 0
  }]
}

# -----------------------------------------------------------------------------
# Public status page (free tier includes 1)
# -----------------------------------------------------------------------------

resource "uptimerobot_psp" "main" {
  name        = "Missing Table Status"
  monitor_ids = [uptimerobot_monitor.frontend.id, uptimerobot_monitor.api.id]
}
