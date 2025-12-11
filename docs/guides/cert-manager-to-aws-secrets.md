# Migrating Certificates from DigitalOcean (cert-manager) to AWS Secrets Manager

## Understanding Your Setup

### How cert-manager Works

1. **ClusterIssuer** (lines 98-120 in `main.tf`): 
   - Defines how to get certificates (Let's Encrypt via DNS-01 challenge)
   - Uses DigitalOcean DNS API for validation
   - Named `letsencrypt-prod`

2. **Certificate Request**: 
   - When you create an Ingress resource with cert-manager annotations, it automatically creates a `Certificate` resource
   - The Certificate resource requests a cert from Let's Encrypt using the ClusterIssuer

3. **Certificate Storage**:
   - cert-manager stores the certificate in a Kubernetes Secret
   - Secret type: `kubernetes.io/tls`
   - Contains: `tls.crt` (certificate), `tls.key` (private key), `ca.crt` (CA chain)

## Finding Your Certificate

### Step 1: List Certificate Resources

```bash
# List all Certificate resources (cert-manager CRDs)
kubectl get certificates --all-namespaces

# Look for certificates related to missingtable.com
kubectl get certificates --all-namespaces | grep missingtable
```

### Step 2: Find the Kubernetes Secret

cert-manager creates a Secret with the same name as the Certificate resource (or as specified in the Certificate spec).

```bash
# List all TLS secrets (cert-manager creates type: kubernetes.io/tls)
kubectl get secrets --all-namespaces -o json | jq '.items[] | select(.type=="kubernetes.io/tls") | {name: .metadata.name, namespace: .metadata.namespace}'

# Or search for secrets containing "missingtable" or "tls"
kubectl get secrets --all-namespaces | grep -E "missingtable|tls"

# Common patterns cert-manager uses:
# - {domain}-tls (e.g., missingtable-com-tls)
# - tls-{domain}
# - The name specified in your Certificate resource
```

### Step 3: Check Your Ingress Resource

The Ingress resource will tell you which secret it's using:

```bash
# List all ingresses
kubectl get ingress --all-namespaces

# Get details of a specific ingress (replace with your ingress name/namespace)
kubectl get ingress <ingress-name> -n <namespace> -o yaml

# Look for:
# - annotations: cert-manager.io/cluster-issuer: "letsencrypt-prod"
# - spec.tls[].secretName: This is the secret name where cert is stored
```

### Step 4: Inspect the Certificate Secret

Once you find the secret name, inspect it:

```bash
# Get the secret (replace with actual name and namespace)
kubectl get secret <secret-name> -n <namespace> -o yaml

# View just the certificate data (base64 encoded)
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d

# View the private key (base64 encoded)
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.tls\.key}' | base64 -d
```

## Migration Process

### Option 1: Use the Migration Script (Recommended)

The script we created handles everything automatically:

```bash
cd scripts
source .venv/bin/activate

# First, list secrets to find the right one
python migrate-cert-to-aws.py list-secrets --namespace <your-namespace>

# Then migrate (replace with actual secret name if auto-detection fails)
python migrate-cert-to-aws.py missingtable.com --namespace <your-namespace> --secret-name <actual-secret-name>
```

### Option 2: Manual Migration

If you prefer to do it manually:

```bash
# 1. Get the secret
SECRET_NAME="missingtable-com-tls"  # Replace with actual name
NAMESPACE="default"  # Replace with actual namespace

# 2. Extract certificate and key
kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/cert.pem
kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.tls\.key}' | base64 -d > /tmp/key.pem
kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/ca.pem 2>/dev/null || echo ""

# 3. Build fullchain
cat /tmp/cert.pem /tmp/ca.pem > /tmp/fullchain.pem

# 4. Get expiration date
openssl x509 -in /tmp/cert.pem -noout -enddate

# 5. Upload to AWS Secrets Manager
aws secretsmanager create-secret \
  --name "missingtable.com-tls" \
  --secret-string "{\"certificate\":\"$(cat /tmp/cert.pem | tr '\n' '\\n')\",\"private_key\":\"$(cat /tmp/key.pem | tr '\n' '\\n')\",\"fullchain\":\"$(cat /tmp/fullchain.pem | tr '\n' '\\n')\",\"expiration_date\":\"$(openssl x509 -in /tmp/cert.pem -noout -enddate | cut -d= -f2 | xargs -I {} date -j -f '%b %d %H:%M:%S %Y %Z' '{}' '+%Y-%m-%dT%H:%M:%SZ')\"}"
```

## Common Secret Name Patterns

cert-manager typically names secrets based on:

1. **Certificate resource name**: If Certificate is named `missingtable-com-tls`, secret is `missingtable-com-tls`
2. **Ingress annotation**: If Ingress has `cert-manager.io/cluster-issuer: letsencrypt-prod` and `spec.tls[].secretName: my-tls-secret`, secret is `my-tls-secret`
3. **Default pattern**: `{domain-with-dots-replaced}-tls` (e.g., `missingtable-com-tls`)

## Troubleshooting

### Secret Not Found

```bash
# Check if Certificate resource exists
kubectl get certificates --all-namespaces

# Check Certificate status
kubectl describe certificate <cert-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check CertificateRequest (cert-manager creates these)
kubectl get certificaterequests --all-namespaces
```

### Certificate Not Ready

```bash
# Check Certificate status
kubectl get certificate <cert-name> -n <namespace> -o yaml

# Look for:
# - status.conditions[].type: Ready
# - status.conditions[].status: True/False
# - status.conditions[].message: Error messages if failed
```

## Next Steps After Migration

1. **Verify in AWS**:
   ```bash
   aws secretsmanager get-secret-value --secret-id missingtable.com-tls | jq -r .SecretString | jq .
   ```

2. **Update Lambda function** to use the certificate from Secrets Manager

3. **Set up automatic renewal** via the Lambda function (it will check expiration and renew as needed)
