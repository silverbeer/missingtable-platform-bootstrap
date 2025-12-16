variable "alerts_path" {
  description = "Path to directory containing alert YAML files"
  type        = string
}

variable "folder_title" {
  description = "Grafana folder name for alerts"
  type        = string
  default     = "Alerts"
}

variable "datasource_uid" {
  description = "UID of the Prometheus datasource"
  type        = string
  default     = "grafanacloud-prom"
}

variable "contact_point" {
  description = "Name of the contact point for notifications"
  type        = string
}

variable "default_group_wait" {
  description = "Default time to wait before sending grouped alerts"
  type        = string
  default     = "30s"
}

variable "default_repeat_interval" {
  description = "Default interval between repeated notifications"
  type        = string
  default     = "4h"
}
