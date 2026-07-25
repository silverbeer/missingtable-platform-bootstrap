output "match_photos_bucket_name" {
  description = "Name of the R2 bucket holding match photos."
  value       = cloudflare_r2_bucket.match_photos.name
}

output "android_releases_bucket_name" {
  description = "Name of the R2 bucket holding Android APK releases (private; served via backend presigned URLs)."
  value       = cloudflare_r2_bucket.android_releases.name
}
