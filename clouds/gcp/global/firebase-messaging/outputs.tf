output "project_number" {
  description = "GCP project number (FCM sender ID)."
  value       = data.google_project.this.number
}

output "android_app_ids" {
  description = "Firebase app IDs, keyed like var.android_apps."
  value       = { for k, app in google_firebase_android_app.apps : k => app.app_id }
}

# Not a secret in the usual sense (it ships inside the APK), but it holds the
# Android API key, so keep it out of plan/apply logs. Read with:
#   tofu output -json google_services_json | jq -r .prod > app/src/prod/google-services.json
output "google_services_json" {
  description = "Decoded google-services.json per app, keyed like var.android_apps."
  value       = { for k, cfg in data.google_firebase_android_app_config.apps : k => base64decode(cfg.config_file_contents) }
  sensitive   = true
}

output "fcm_sender_email" {
  description = "Service account the backend authenticates as for FCM HTTP v1."
  value       = google_service_account.fcm_sender.email
}
