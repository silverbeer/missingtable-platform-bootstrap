# =============================================================================
# DNS Configuration Variables
# =============================================================================

variable "domains" {
  description = "Map of domains to manage"
  type = map(object({
    records = list(object({
      type     = string           # A, AAAA, CNAME, MX, TXT, NS, SRV
      name     = string           # @ for root, or subdomain
      value    = string           # IP or target
      priority = optional(number) # For MX records
      ttl      = optional(number, 3600)
    }))
  }))
}
