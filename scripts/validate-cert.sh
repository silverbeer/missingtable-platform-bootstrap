#!/usr/bin/env bash
# Validate a TLS cert/key stored in AWS Secrets Manager.
# Expects the secret JSON to contain: certificate, private_key, and optionally fullchain.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validate-cert.sh -s <secret-id> [-r <region>] [-o <output-dir>] [-c <ca-bundle>]

Examples:
  validate-cert.sh -s missingtable.com-tls -r us-east-2
  validate-cert.sh -s missingtable.com-tls -o /tmp/cert-check

Flags:
  -s  AWS Secrets Manager secret id (required)
  -r  AWS region (optional; defaults to AWS CLI config)
  -o  Directory to write cert files (optional; defaults to temp dir and deletes on exit)
  -c  CA bundle path to verify the leaf cert (optional; e.g., /etc/ssl/cert.pem)
EOF
}

SECRET_ID=""
AWS_REGION=""
OUTPUT_DIR=""
CA_BUNDLE=""

while getopts "s:r:o:c:h" opt; do
  case "$opt" in
    s) SECRET_ID="$OPTARG" ;;
    r) AWS_REGION="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    c) CA_BUNDLE="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

if [[ -z "$SECRET_ID" ]]; then
  usage
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found on PATH" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found on PATH" >&2
  exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl not found on PATH" >&2
  exit 1
fi

cleanup() {
  if [[ -z "${KEEP_DIR:-}" && -d "$WORKDIR" ]]; then
    rm -rf "$WORKDIR"
  fi
}

if [[ -n "$OUTPUT_DIR" ]]; then
  mkdir -p "$OUTPUT_DIR"
  WORKDIR="$OUTPUT_DIR"
  KEEP_DIR=1
else
  WORKDIR="$(mktemp -d)"
  trap cleanup EXIT
fi

aws_args=(secretsmanager get-secret-value --secret-id "$SECRET_ID" --query SecretString --output text)
if [[ -n "$AWS_REGION" ]]; then
  aws_args+=(--region "$AWS_REGION")
fi

echo "Fetching secret ${SECRET_ID}..."
secret_string="$(aws "${aws_args[@]}")"

cert="$(printf '%s' "$secret_string" | jq -r '.certificate // empty')"
key="$(printf '%s' "$secret_string" | jq -r '.private_key // empty')"
fullchain="$(printf '%s' "$secret_string" | jq -r '.fullchain // empty')"

if [[ -z "$cert" || -z "$key" ]]; then
  echo "Secret missing certificate or private_key fields" >&2
  exit 1
fi

cert_path="$WORKDIR/cert.pem"
key_path="$WORKDIR/key.pem"
fullchain_path="$WORKDIR/fullchain.pem"

printf '%s\n' "$cert" > "$cert_path"
printf '%s\n' "$key" > "$key_path"
if [[ -n "$fullchain" ]]; then
  printf '%s\n' "$fullchain" > "$fullchain_path"
fi

echo "Stored cert/key at ${WORKDIR}"

echo "=== Certificate summary ==="
openssl x509 -in "$cert_path" -noout -subject -issuer -enddate

echo "=== Fingerprints ==="
openssl x509 -in "$cert_path" -noout -fingerprint -sha256

echo "=== Public key match ==="
cert_pub_hash="$(openssl x509 -in "$cert_path" -noout -pubkey | openssl sha256)"
key_pub_hash="$(openssl pkey -in "$key_path" -pubout | openssl sha256)"
echo "cert pubkey: $cert_pub_hash"
echo "key  pubkey: $key_pub_hash"
if [[ "$cert_pub_hash" == "$key_pub_hash" ]]; then
  echo "✔ certificate and private key match"
else
  echo "✖ certificate and private key do NOT match" >&2
  exit 1
fi

if [[ -n "$CA_BUNDLE" ]]; then
  echo "=== Chain verification (using CA bundle ${CA_BUNDLE}) ==="
  if [[ ! -f "$CA_BUNDLE" ]]; then
    echo "CA bundle not found at ${CA_BUNDLE}" >&2
  else
    if openssl verify -CAfile "$CA_BUNDLE" "$cert_path"; then
      echo "✔ certificate verifies against provided CA bundle"
    else
      echo "✖ certificate did NOT verify against provided CA bundle; ensure the bundle includes the issuing root" >&2
    fi
  fi
elif [[ -f "$fullchain_path" ]]; then
  chain_certs_count="$(grep -c "BEGIN CERTIFICATE" "$fullchain_path" || true)"
  if [[ "$chain_certs_count" -lt 2 ]]; then
    echo "Fullchain has only the leaf certificate; skipping chain verification (no CA provided)."
  else
    echo "=== Chain verification (using provided fullchain) ==="
    if openssl verify -CAfile "$fullchain_path" "$cert_path"; then
      echo "✔ certificate verifies against provided chain"
    else
      echo "✖ certificate did NOT verify against provided chain (likely missing root CA); this is common if the secret lacks ca.crt" >&2
    fi
  fi
else
  echo "No fullchain present; skipping chain verification."
fi

echo "Done. Files in: $WORKDIR"
