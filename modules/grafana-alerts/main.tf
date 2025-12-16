# =============================================================================
# Grafana Alerts Module
# =============================================================================
# Reads alert definitions from YAML files and creates Grafana alert rules.
#
# Usage:
#   1. Create YAML files in the alerts_path directory
#   2. Each file defines one alert with query, condition, and notifications
#   3. Run tofu apply to sync alerts to Grafana
# =============================================================================

locals {
  # Find all YAML alert files
  alert_files = fileset(var.alerts_path, "*.yaml")

  # Parse each YAML file into a map keyed by filename (without extension)
  alerts = {
    for file in local.alert_files :
    trimsuffix(file, ".yaml") => yamldecode(file("${var.alerts_path}/${file}"))
  }
}

# Folder to contain all alerts
resource "grafana_folder" "alerts" {
  title = var.folder_title
}

# Create a rule group for each alert file
resource "grafana_rule_group" "alert" {
  for_each = local.alerts

  name             = each.value.name
  folder_uid       = grafana_folder.alerts.uid
  interval_seconds = 60

  rule {
    name      = each.value.name
    condition = "C"

    # Query A: The PromQL expression
    data {
      ref_id         = "A"
      datasource_uid = var.datasource_uid

      relative_time_range {
        from = lookup(each.value.query, "range_seconds", 300)
        to   = 0
      }

      model = jsonencode({
        expr          = each.value.query.expr
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    # Query B: Reduce to last value
    data {
      ref_id         = "B"
      datasource_uid = "__expr__"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "reduce"
        expression = "A"
        reducer    = "last"
        refId      = "B"
      })
    }

    # Condition C: Threshold comparison
    data {
      ref_id         = "C"
      datasource_uid = "__expr__"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "threshold"
        expression = "B"
        refId      = "C"
        conditions = [{
          type = each.value.condition.operator
          evaluator = {
            type   = each.value.condition.operator
            params = [each.value.condition.threshold]
          }
        }]
      })
    }

    # Convert pending_duration string to duration
    for            = lookup(each.value, "pending_duration", "0s")
    no_data_state  = lookup(each.value, "no_data_state", "OK")
    exec_err_state = lookup(each.value, "error_state", "Alerting")
    is_paused      = false

    labels = {
      severity = each.value.severity
      service  = each.value.service
    }

    annotations = {
      summary     = each.value.name
      description = each.value.description
    }
  }
}

# Create notification policies for each unique service
resource "grafana_notification_policy" "alerts" {
  group_by      = ["alertname"]
  contact_point = "grafana-default-email"

  # Create a policy for each unique service in the alerts
  dynamic "policy" {
    for_each = toset([for k, v in local.alerts : v.service])
    content {
      matcher {
        label = "service"
        match = "="
        value = policy.value
      }
      contact_point   = var.contact_point
      group_wait      = var.default_group_wait
      group_interval  = "5m"
      repeat_interval = var.default_repeat_interval
    }
  }
}
