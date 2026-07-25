# Cloudflare R2 storage — foundation stack (Linear SB-314).
#
# This stack brings the existing, hand-created R2 usage under IaC and is the
# shared foundation the Android APK bucket (SB-313) builds on.
#
# ── Bootstrapping (one-time, before `tofu apply`) ────────────────────────────
#   1. In the Cloudflare dashboard, create an API token with
#      "Workers R2 Storage: Edit" on the account.
#   2. Copy clouds/cloudflare/global/r2/terraform.tfvars.example to
#      terraform.tfvars (gitignored) and fill in account_id + api_token.
#   3. `tofu init`
#
# ── Import the existing photo bucket (do NOT let plan try to recreate it) ─────
#   The mt-match-photos bucket already exists (backend match-photo storage,
#   SB-31). Import it, then run plan to reconcile. The v5 import ID is three
#   urlencoded segments: "<account_id>/<bucket_name>/<jurisdiction>", where
#   jurisdiction is "default" for a standard bucket (else "eu" / "fedramp"):
#     tofu import cloudflare_r2_bucket.match_photos "<account_id>/mt-match-photos/default"
#     tofu plan   # add any attributes plan reports as drift (e.g. jurisdiction, location)

resource "cloudflare_r2_bucket" "match_photos" {
  account_id = var.cloudflare_account_id
  name       = "mt-match-photos"

  # location / storage_class are set at creation and returned by the API. After
  # the import, `tofu plan` will show whether they need to be pinned here to
  # match the existing bucket — add them then rather than guessing now.

  lifecycle {
    # This bucket holds live production match photos — guard against an
    # accidental destroy/recreate from a schema mismatch during import.
    prevent_destroy = true
  }
}

# ── Android APK distribution bucket (SB-313) ─────────────────────────────────
# PRIVATE, like the photo bucket. MT is invite-only, so the APK must not be
# anonymously downloadable. CI uploads the signed APK here; the MT backend
# hands authenticated users a short-lived presigned URL (GET /api/android/apk-url).
resource "cloudflare_r2_bucket" "android_releases" {
  account_id = var.cloudflare_account_id
  name       = "mt-android-releases"
}

# Keep the managed r2.dev public domain DISABLED — the bucket stays private and
# is only reachable via backend-minted presigned URLs. (The resource is kept at
# enabled=false rather than removed so the disabled state is managed in code; a
# branded downloads.missingtable.com custom domain is intentionally NOT bound.)
resource "cloudflare_r2_managed_domain" "android_releases" {
  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.android_releases.name
  enabled     = false
}
