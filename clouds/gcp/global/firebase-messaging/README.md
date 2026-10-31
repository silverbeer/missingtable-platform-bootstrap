# Firebase Cloud Messaging (GCP, global)

Firebase lives in its own project, `mta-firebase-45c8a`, so the backend can send
Android push over FCM HTTP v1 (**SB-1463**, backend side; **SB-1465**, this stack).
That project has **no billing account** (Spark plan), so nothing in it can be
charged. The $1 budget watches `missing-table`, the billed project.
First GCP stack in the repo.

## One-time manual bootstrap (not in Terraform)

Terraform can't do these itself:

1. **Create the Firebase project in the Firebase console.** On 2026-10-31,
   `projects.addFirebase` returned a bare `403 The caller does not have permission`
   for `missing-table`, even for its owner after accepting the Firebase terms. The
   console-created project is adopted by the `import` block in `main.tf`.
2. **Enable the APIs Terraform needs before it can enable anything else:**
   ```bash
   gcloud services enable serviceusage.googleapis.com --project missing-table
   gcloud services enable iam.googleapis.com --project mta-firebase-45c8a
   ```

## What's here

- APIs on the Firebase project: `firebase`, `fcm`, `firebaseinstallations`, `iam`.
  `billingbudgets` on `missing-table`. All `disable_on_destroy = false`.
- `google_firebase_project`, imported (see above).
- One `google_firebase_android_app` per distinct applicationId in
  `missing-table-android/app/build.gradle.kts`: `com.missingtable.scorer` (prod
  flavor) and `com.missingtable.scorer.local` (local flavor's `.local` suffix).
  FCM tokens are per package, so both need a registration.
- `fcm-sender` service account with `roles/firebasecloudmessaging.admin` — the
  smallest predefined role holding `cloudmessaging.messages.create`
  (`roles/cloudmessaging.editor` has the identical permission set).
- **No service-account key resource.** Its private key would be stored in
  plaintext in state; the key is created by `scripts/set-fcm-aws-secret.sh`.
- A $1/month billing budget on `missing-table` (`budget_project_id`): emails at 50% and 100% actual spend
  and 100% forecast, to the billing account's default IAM recipients.

## Auth

gcloud ADC (`gcloud auth application-default login`) as a project owner who is
also billing admin on the billing account. Providers set
`user_project_override = true` and a `billing_project` (the Firebase project; the
`google.budget` alias uses `missing-table`), because the Firebase and Budgets APIs
refuse end-user ADC calls without a quota project.

## Apply order

1. **Apply this stack.**
   ```bash
   cp terraform.tfvars.example terraform.tfvars   # values are not secrets
   tofu init && tofu plan && tofu apply
   ```
2. **Human runs the key script** (creates the SA key, merges it into AWS SM
   `missing-table-app-secrets` as `fcm_service_account_json`):
   ```bash
   ./scripts/set-fcm-aws-secret.sh
   ```
3. **Apply the Linode env** (`clouds/linode/environments/dev`) — adds the ESO
   mapping `fcm-service-account-json` ← `fcm_service_account_json`. Step 2 must
   come first: a mapped property missing from AWS fails the whole sync.
4. **Force-sync and restart the backend:**
   ```bash
   kubectl annotate externalsecret missing-table-app-secrets -n missing-table force-sync=$(date +%s) --overwrite
   kubectl rollout restart deployment -n missing-table -l app.kubernetes.io/component=backend
   ```
5. **Verify:** sign in on a device running the app, then
   `POST /api/users/me/notifications/test` — the device should receive a push.

## google-services.json

The Android app needs one per flavor. It is not a secret (it ships in the APK)
but holds the Android API key, so the output is marked sensitive:

```bash
tofu output -json google_services_json | jq -r .prod  > google-services.prod.json
tofu output -json google_services_json | jq -r .local > google-services.local.json
```

## Key rotation

Re-run `scripts/set-fcm-aws-secret.sh`. It creates a new key, prints its id, and
prints a `gcloud iam service-accounts keys delete` command for every other
user-managed key. Run those after the backend has restarted on the new key.

## State

S3 backend `missingtable-terraform-state`, key
`gcp/global/firebase-messaging/terraform.tfstate`.

## Cost

$0. FCM is no-cost on every Firebase plan, budgets and their email alerts are
free, and no new AWS secret is created (one property added to the existing
`missing-table-app-secrets`).
