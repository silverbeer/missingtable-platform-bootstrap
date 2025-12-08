# =============================================================================
# DNS Management for All Domains
# =============================================================================

# Create domain zones
resource "digitalocean_domain" "domains" {
  for_each = var.domains
  name     = each.key
}

# Flatten records for easier iteration
locals {
  dns_records = flatten([
    for domain, config in var.domains : [
      for record in config.records : {
        domain   = domain
        type     = record.type
        name     = record.name
        value    = record.value
        priority = record.priority
        ttl      = record.ttl
        # Create unique key for each record
        key      = "${domain}-${record.type}-${record.name}-${record.value}"
      }
    ]
  ])
}

# Create DNS records
resource "digitalocean_record" "records" {
  for_each = { for r in local.dns_records : r.key => r }

  domain   = each.value.domain
  type     = each.value.type
  name     = each.value.name
  value    = each.value.value
  priority = each.value.priority
  ttl      = each.value.ttl

  depends_on = [digitalocean_domain.domains]
}
