provider "cloudflare" {
  # A Cloudflare API token with R2 admin permissions (Account > Workers R2 Storage:
  # Edit). This is the token the provider authenticates WITH — it is NOT the same
  # as the R2 S3 access-key/secret the apps use (those live in AWS Secrets Manager
  # at missing-table/cloudflare/r2). Supply via terraform.tfvars (gitignored).
  api_token = var.cloudflare_api_token
}
