output "nameservers" {
  description = "The name servers for the domain in Route 53"
  value       = aws_route53_zone.main.name_servers
}

output "zone_id" {
  description = "The zone ID for the domain"
  value       = aws_route53_zone.main.zone_id
}

output "external_secrets_access_id" {
  description = "The access ID for the external secrets user"
  value       = aws_iam_access_key.external_secrets.id
}

output "external_secrets_access_key" {
  description = "The access key for the external secrets user"
  value       = aws_iam_access_key.external_secrets.secret
  sensitive   = true
}

output "qualityplaybook_nameservers" {
  description = "The name servers for qualityplaybook.dev in Route 53"
  value       = aws_route53_zone.qualityplaybook.name_servers
}

output "qualityplaybook_zone_id" {
  description = "The zone ID for qualityplaybook.dev"
  value       = aws_route53_zone.qualityplaybook.zone_id
}
