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