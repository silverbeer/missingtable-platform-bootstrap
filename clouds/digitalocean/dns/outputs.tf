output "domains" {
  description = "Managed domains"
  value       = [for d in digitalocean_domain.domains : d.name]
}

output "nameservers" {
  description = "DigitalOcean nameservers (point your registrar here)"
  value = [
    "ns1.digitalocean.com",
    "ns2.digitalocean.com",
    "ns3.digitalocean.com"
  ]
}

output "records" {
  description = "All DNS records created"
  value = {
    for key, record in digitalocean_record.records : key => {
      domain = record.domain
      type   = record.type
      name   = record.name
      value  = record.value
      fqdn   = record.fqdn
    }
  }
}

output "verification_commands" {
  description = "Commands to verify DNS"
  value = <<-EOT
    # Check nameservers (should show ns*.digitalocean.com)
    dig ${join(" ", [for d in digitalocean_domain.domains : d.name])} NS +short

    # Check A records
    %{for key, record in digitalocean_record.records~}
    %{if record.type == "A"~}
    dig ${record.fqdn} +short  # Should return: ${record.value}
    %{endif~}
    %{endfor~}
  EOT
}
