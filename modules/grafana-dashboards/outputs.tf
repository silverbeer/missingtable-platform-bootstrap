output "folder_uid" {
  description = "UID of the Grafana folder containing dashboards"
  value       = grafana_folder.dashboards.uid
}

output "dashboard_names" {
  description = "Names of all deployed dashboards"
  value       = [for k, v in local.dashboards : k]
}

output "dashboard_count" {
  description = "Number of dashboards deployed"
  value       = length(local.dashboards)
}
