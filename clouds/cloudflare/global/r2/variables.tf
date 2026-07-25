variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the R2 buckets (same account as the existing mt-match-photos bucket; value also in AWS Secrets Manager missing-table/cloudflare/r2)."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with R2 admin permissions, used by the provider to manage buckets. Distinct from the R2 S3 access keys the apps use."
  type        = string
  sensitive   = true
}
