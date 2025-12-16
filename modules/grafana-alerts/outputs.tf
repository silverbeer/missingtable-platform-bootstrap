output "folder_uid" {
  description = "UID of the Grafana folder containing alerts"
  value       = grafana_folder.alerts.uid
}

output "alert_names" {
  description = "Names of all deployed alerts"
  value       = [for k, v in local.alerts : v.name]
}

output "alert_count" {
  description = "Number of alerts deployed"
  value       = length(local.alerts)
}
