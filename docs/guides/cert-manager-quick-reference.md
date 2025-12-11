# Quick Reference: Accessing cert-manager Certificates

## Quick Commands to Find Your Certificate

### 1. Find Certificate Resources

```bash
# List all certificates
kubectl get certificates --all-namespaces

# Get details of a specific certificate
kubectl get certificate <cert-name> -n <namespace> -o yaml
```

### 2. Find the Secret (Where Certificate is Stored)

```bash
# List all TLS secrets
kubectl get secrets --all-namespaces | grep "kubernetes.io/tls"

# Or use the script we created
cd scripts && source .venv/bin/activate
python migrate-cert-to-aws.py list-secrets --namespace default
```

### 3. Check Ingress (Tells You Secret Name)

```bash
# List all ingresses
kubectl get ingress --all-namespaces

# Get ingress details (shows which secret it uses)
kubectl get ingress <ingress-name> -n <namespace> -o yaml | grep -A 5 "tls:"
```

### 4. Extract Certificate Data

```bash
# Replace SECRET_NAME and NAMESPACE with actual values
SECRET_NAME="missingtable-com-tls"
NAMESPACE="default"

# View certificate (base64 decoded)
kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.tls\.crt}' | base64 -d

# View private key (base64 decoded)
kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.tls\.key}' | base64 -d

# View CA chain (if present)
kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 -d
```

### 5. Check Certificate Status

```bash
# Check if certificate is ready
kubectl get certificate <cert-name> -n <namespace>

# Detailed status
kubectl describe certificate <cert-name> -n <namespace>
```

## Typical Workflow

```bash
# Step 1: Find your ingress
kubectl get ingress --all-namespaces

# Step 2: Check which secret the ingress uses
kubectl get ingress <ingress-name> -n <namespace> -o jsonpath='{.spec.tls[0].secretName}'

# Step 3: Verify the secret exists
kubectl get secret <secret-name> -n <namespace>

# Step 4: Use migration script
cd scripts && source .venv/bin/activate
python migrate-cert-to-aws.py missingtable.com --namespace <namespace> --secret-name <secret-name>
```

## Understanding cert-manager Flow

```
Ingress Resource
  ↓ (has annotation: cert-manager.io/cluster-issuer: letsencrypt-prod)
Certificate Resource (created automatically)
  ↓ (requests cert from Let's Encrypt via ClusterIssuer)
CertificateRequest (created by cert-manager)
  ↓ (validates via DNS-01 challenge)
Kubernetes Secret (type: kubernetes.io/tls)
  ├── tls.crt (certificate)
  ├── tls.key (private key)
  └── ca.crt (CA chain, optional)
```

## Your Setup Details

Based on `main.tf`:
- **ClusterIssuer**: `letsencrypt-prod` (namespace: cert-manager)
- **Challenge Type**: DNS-01 (DigitalOcean DNS)
- **Domain**: `missingtable.com`
- **Expected Secret Name**: Likely `missingtable-com-tls` or similar

