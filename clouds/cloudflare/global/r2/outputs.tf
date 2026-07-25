output "match_photos_bucket_name" {
  description = "Name of the R2 bucket holding match photos."
  value       = cloudflare_r2_bucket.match_photos.name
}
