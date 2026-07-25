output "match_photos_bucket_name" {
  description = "Name of the R2 bucket holding match photos."
  value       = cloudflare_r2_bucket.match_photos.name
}

output "android_releases_bucket_name" {
  description = "Name of the R2 bucket holding Android APK releases."
  value       = cloudflare_r2_bucket.android_releases.name
}

output "android_releases_public_url" {
  description = "Public r2.dev URL for the Android releases bucket (until a branded custom domain is bound). The MT web-UI install button links here."
  value       = cloudflare_r2_managed_domain.android_releases.domain
}
