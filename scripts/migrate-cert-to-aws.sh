#!/usr/bin/env bash
# Simple helper to copy a Kubernetes TLS secret into AWS Secrets Manager.
# Requires: kubectl, aws CLI, jq, base64.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: migrate-cert-to-aws.sh -n <namespace> -s <k8s_secret_name> [-a <aws_secret_name>] [-r <aws_region>]

Examples:
  migrate-cert-to-aws.sh -n missing-table -s missingtable.com-tls -a missingtable.com-tls
  migrate-cert-to-aws.sh -n default -s my-cert

Flags:
  -n  Kubernetes namespace (required)
  -s  Kubernetes secret name (required)
  -a  AWS Secrets Manager name (default: <k8s_secret_name>)
  -r  AWS region (optional; falls back to AWS CLI default)
EOF
}

NS=""
K8S_SECRET=""
AWS_SECRET_NAME=""
AWS_REGION=""

while getopts "n:s:a:r:h" opt; do
  case "$opt" in
    n) NS="$OPTARG" ;;
    s) K8S_SECRET="$OPTARG" ;;
    a) AWS_SECRET_NAME="$OPTARG" ;;
    r) AWS_REGION="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

if [[ -z "$NS" || -z "$K8S_SECRET" ]]; then
  usage
  exit 1
fi

AWS_SECRET_NAME="${AWS_SECRET_NAME:-$K8S_SECRET}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found on PATH" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found on PATH" >&2
  exit 1
fi
if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found on PATH" >&2
  exit 1
fi

echo "Fetching secret ${K8S_SECRET} from namespace ${NS}..."
secret_json="$(kubectl get secret "$K8S_SECRET" -n "$NS" -o json)"

tls_crt_b64="$(echo "$secret_json" | jq -r '.data["tls.crt"] // empty')"
tls_key_b64="$(echo "$secret_json" | jq -r '.data["tls.key"] // empty')"
ca_crt_b64="$(echo "$secret_json" | jq -r '.data["ca.crt"] // empty')"

if [[ -z "$tls_crt_b64" || -z "$tls_key_b64" ]]; then
  echo "Secret missing tls.crt or tls.key" >&2
  exit 1
fi

tls_crt="$(printf '%s' "$tls_crt_b64" | base64 -d)"
tls_key="$(printf '%s' "$tls_key_b64" | base64 -d)"
ca_crt=""
if [[ -n "$ca_crt_b64" ]]; then
  ca_crt="$(printf '%s' "$ca_crt_b64" | base64 -d || true)"
fi

fullchain="$tls_crt"
if [[ -n "$ca_crt" ]]; then
  fullchain="${tls_crt}
${ca_crt}"
fi

payload="$(jq -n \
  --arg certificate "$tls_crt" \
  --arg private_key "$tls_key" \
  --arg fullchain "$fullchain" \
  '{certificate:$certificate, private_key:$private_key, fullchain:$fullchain}')"

echo "Writing to AWS Secrets Manager: ${AWS_SECRET_NAME}"
aws_args=()  # initialize to satisfy set -u
if [[ -n "$AWS_REGION" ]]; then
  aws_args+=(--region "$AWS_REGION")
fi

if aws "${aws_args[@]}" secretsmanager describe-secret --secret-id "$AWS_SECRET_NAME" >/dev/null 2>&1; then
  aws "${aws_args[@]}" secretsmanager put-secret-value \
    --secret-id "$AWS_SECRET_NAME" \
    --secret-string "$payload" >/dev/null
  echo "Updated secret ${AWS_SECRET_NAME}"
else
  aws "${aws_args[@]}" secretsmanager create-secret \
    --name "$AWS_SECRET_NAME" \
    --secret-string "$payload" >/dev/null
  echo "Created secret ${AWS_SECRET_NAME}"
fi

echo "Done."
