variable "dashboards_path" {
  description = "Path to directory containing dashboard JSON files"
  type        = string
}

variable "folder_title" {
  description = "Grafana folder name for dashboards"
  type        = string
  default     = "Dashboards"
}
