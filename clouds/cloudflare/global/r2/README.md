# Cloudflare R2 (global)

Manages Cloudflare R2 storage as IaC. Foundation stack for **SB-314** (bring the
hand-created R2 usage under Terraform) and the base the Android APK bucket
(**SB-313**) builds on.

## What's here

- `mt-match-photos` — existing bucket for backend match-photo storage (SB-31).
  **Imported**, not created (see below).
- `mt-android-releases` — **private** APK bucket (SB-313). CI uploads the signed
  APK here; the MT backend hands authenticated users a short-lived presigned URL
  (`GET /api/android/apk-url`), since MT is invite-only. The managed `r2.dev`
  public domain is kept **disabled**.

## Auth model (two different credentials)

- **Provider token** (`cloudflare_api_token` var) — a Cloudflare API token with
  *Workers R2 Storage: Edit*. Used by Terraform to manage buckets. Lives in
  `terraform.tfvars` (gitignored).
- **R2 S3 access keys** — what the *apps/CI* use to read/write objects. Separate
  credential, stored in AWS Secrets Manager `missing-table/cloudflare/r2`. Not
  managed here (yet).

## First run

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in account_id + api_token
tofu init

# Import the existing photo bucket so plan doesn't try to recreate it.
# v5 import ID = "<account_id>/<bucket>/<jurisdiction>" (jurisdiction "default"
# for a standard bucket; else "eu" / "fedramp"):
tofu import cloudflare_r2_bucket.match_photos "<account_id>/mt-match-photos/default"
tofu plan     # pin any attributes (e.g. jurisdiction, location) plan reports as drift
```

## State

S3 backend `missingtable-terraform-state`, key `cloudflare/global/r2/terraform.tfstate`.

## Cost

R2 always-free tier: 10 GB storage + Class A/B op allowances, **egress always
free**. At current usage this stack is $0.

## Notes

- Provider is **v5** (auto-generated rewrite; schemas differ from v4 examples).
- A branded `downloads.missingtable.com` custom domain on R2 requires the
  `missingtable.com` DNS zone on Cloudflare (Route53→CF cutover) — out of scope
  here.
