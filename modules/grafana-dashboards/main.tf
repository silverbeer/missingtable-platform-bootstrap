# =============================================================================
# Grafana Dashboards Module
# =============================================================================
# Reads dashboard definitions from JSON files and deploys to Grafana.
#
# Usage:
#   1. Create JSON files in the dashboards_path directory
#   2. Each file is a complete Grafana dashboard definition
#   3. Run tofu apply to sync dashboards to Grafana
# =============================================================================

locals {
  # Find all JSON dashboard files
  dashboard_files = fileset(var.dashboards_path, "*.json")

  # Create a map keyed by filename (without extension)
  dashboards = {
    for file in local.dashboard_files :
    trimsuffix(file, ".json") => file
  }
}

# Folder to contain all dashboards
resource "grafana_folder" "dashboards" {
  title = var.folder_title
}

# Create a dashboard for each JSON file
resource "grafana_dashboard" "dashboard" {
  for_each = local.dashboards

  folder      = grafana_folder.dashboards.id
  config_json = file("${var.dashboards_path}/${each.value}")
  overwrite   = true
}
