#!/usr/bin/env bash
#
# Create a key for the `fcm-sender` service account (clouds/gcp/global/
# firebase-messaging) and merge it into the `missing-table-app-secrets` AWS
# Secrets Manager secret (a JSON blob), under `fcm_service_account_json`.
# External Secrets Operator maps it into k8s `missing-table-secrets` as
# `fcm-service-account-json`, which the backend reads as
# FCM_SERVICE_ACCOUNT_JSON (SB-1463, SB-1465).
#
#   ./scripts/set-fcm-aws-secret.sh
#
# The key is created here rather than as a google_service_account_key resource
# so the private key never lands in Terraform state. It never appears on screen,
# in shell history, or in any process's arguments — it goes gcloud → a 0600 temp
# file → jq → a 0600 temp file → AWS.
#
# Re-running rotates: it creates a NEW key and prints the delete command for
# every other user-managed key on the account. Delete those only after the
# backend has restarted on the new one.
#
# Env overrides:
#   AWS_SECRET_ID  default: missing-table-app-secrets
#   AWS_REGION     default: us-east-2
#   FCM_SA_EMAIL   default: fcm-sender@mta-firebase-45c8a.iam.gserviceaccount.com
set -euo pipefail

SECRET_ID="${AWS_SECRET_ID:-missing-table-app-secrets}"
REGION="${AWS_REGION:-us-east-2}"
SA_EMAIL="${FCM_SA_EMAIL:-fcm-sender@mta-firebase-45c8a.iam.gserviceaccount.com}"

for c in gcloud aws jq; do
  command -v "$c" >/dev/null || { echo "✗ missing command: $c" >&2; exit 1; }
done
aws sts get-caller-identity >/dev/null 2>&1 || { echo "✗ aws not authenticated" >&2; exit 1; }
[ -n "$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)" ] ||
  { echo "✗ gcloud not authenticated (gcloud auth login)" >&2; exit 1; }
gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1 ||
  { echo "✗ service account not found: ${SA_EMAIL} (apply clouds/gcp/global/firebase-messaging first)" >&2; exit 1; }

keyfile="$(mktemp)"
tmp="$(mktemp)"
chmod 600 "$keyfile" "$tmp"
trap 'rm -f "$keyfile" "$tmp"' EXIT

echo "→ creating a key for ${SA_EMAIL}"
gcloud iam service-accounts keys create "$keyfile" --iam-account="$SA_EMAIL" >/dev/null 2>&1 ||
  { echo "✗ key creation failed: gcloud iam service-accounts keys create <file> --iam-account=${SA_EMAIL}" >&2; exit 1; }
jq -e '.type == "service_account" and (.private_key_id | length > 0)' "$keyfile" >/dev/null ||
  { echo "✗ gcloud did not write a service-account key" >&2; exit 1; }
key_id="$(jq -r .private_key_id "$keyfile")"

echo "→ merging fcm_service_account_json into AWS Secrets Manager: ${SECRET_ID} (${REGION})"
aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --region "$REGION" \
  --query SecretString --output text |
  jq --rawfile k "$keyfile" '. + {fcm_service_account_json: $k}' > "$tmp"

aws secretsmanager put-secret-value --secret-id "$SECRET_ID" --region "$REGION" \
  --secret-string "file://${tmp}" >/dev/null

echo "✓ done. new key id: ${key_id}"
echo "  keys now: $(jq -r 'keys | join(", ")' "$tmp")"

others="$(gcloud iam service-accounts keys list --iam-account="$SA_EMAIL" --managed-by=user \
  --format='value(name.basename())' | grep -vx "$key_id" || true)"
if [ -n "$others" ]; then
  echo "  other user-managed keys on ${SA_EMAIL} — delete once the backend runs on ${key_id}:"
  while read -r old; do
    echo "  gcloud iam service-accounts keys delete ${old} --iam-account=${SA_EMAIL} --quiet"
  done <<< "$others"
fi

echo "  ESO refreshes hourly; to sync now:"
echo "  kubectl annotate externalsecret missing-table-app-secrets -n missing-table force-sync=\$(date +%s) --overwrite"
