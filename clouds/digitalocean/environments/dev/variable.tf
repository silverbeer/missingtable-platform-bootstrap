variable "database_url" {
  description = "PostgreSQL connection string for Supabase"
  type        = string
}

variable "supabase_url" {
  description = "Supabase project URL"
  type        = string
}

variable "supabase_anon_key" {
  description = "Supabase anonymous key"
  type        = string
}

variable "supabase_jwt_secret" {
  description = "Supabase JWT secret for token verification"
  type        = string
  sensitive   = true
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "ghcr_username" {
  description = "GitHub username for GHCR"
  type        = string
}

variable "ghcr_token" {
  description = "GitHub token with read:packages scope"
  type        = string
  sensitive   = true
}

variable "digitalocean_token" {
  description = "DigitalOcean API token for DNS-01 challenge"
  type        = string
  sensitive   = true
}

variable "aws_access_key_id" {
  description = "AWS access key ID for External Secrets"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key for External Secrets"
  type        = string
  sensitive   = true
}

# =============================================================================
# GRAFANA CLOUD
# =============================================================================

variable "grafana_cloud_prometheus_url" {
  description = "Grafana Cloud Prometheus remote write URL"
  type        = string
}

variable "grafana_cloud_prometheus_username" {
  description = "Grafana Cloud Prometheus username (numeric ID)"
  type        = string
}

variable "grafana_cloud_loki_url" {
  description = "Grafana Cloud Loki push URL"
  type        = string
}

variable "grafana_cloud_loki_username" {
  description = "Grafana Cloud Loki username (numeric ID)"
  type        = string
}

variable "grafana_cloud_access_token" {
  description = "Grafana Cloud API access token"
  type        = string
  sensitive   = true
}