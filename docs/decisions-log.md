# Decisions & Learning Log

Quick notes captured during OpenTofu ninja training. Will be formalized later.

---

## DigitalOcean (Blue Belt → Brown Belt)

### 100% IaC Achieved

**Definition**: `tofu destroy && tofu apply` recreates everything with zero manual steps.

**What's managed:**
| Resource | Count | Purpose |
|----------|-------|---------|
| DOKS Cluster | 1 | Kubernetes control plane + nodes |
| Namespaces | 3 | app, ingress-nginx, cert-manager |
| Deployments | 2 | Frontend, Backend |
| Services | 2 | ClusterIP for both |
| Secrets | 2 | GHCR image pull, DO API token for DNS-01 |
| Helm Releases | 2 | nginx-ingress, cert-manager |
| ClusterIssuer | 1 | Let's Encrypt with DNS-01 (via kubectl provider) |
| Ingress | 1 | TLS + path routing |
| DNS Domain | 1 | missingtable.com |
| DNS Records | 2 | @ and www A records |

**Total**: 18 resources from single `tofu apply`

**Two tricks for true 100% IaC:**

1. **Dynamic DNS** - Records reference ingress IP directly:
```hcl
value = data.kubernetes_service_v1.ingress_nginx.status[0].load_balancer[0].ingress[0].ip
```

2. **DNS-01 challenge** - TLS certificate issued via DNS verification, not HTTP. No timing dependency on DNS propagation.

### DOKS vs EKS - Simplicity Wins

| Component | EKS (AWS) | DOKS (DigitalOcean) |
|-----------|-----------|---------------------|
| VPC | You build it | DO provides it |
| Subnets | You build them | DO handles it |
| IAM Roles | 2 roles needed | None |
| NAT Gateway | $32/month extra | Included |
| Control Plane | $73/month | **Free** |
| Total Setup | ~15 resources | **1 resource** |
| Deploy Time | 15-20 min | 5 min |
| Monthly Cost | ~$164 | ~$48 |

**Key Learning**: Same K8s primitives, fraction of the complexity. Great for learning, great for cost-conscious projects.

### DOKS Cluster - Single Resource

```hcl
resource "digitalocean_kubernetes_cluster" "main" {
  name    = "missingtable-dev"
  region  = "nyc1"
  version = "1.32.10-do.1"

  node_pool {
    name       = "default-pool"
    size       = "s-2vcpu-4gb"  # Human-readable sizing!
    node_count = 2
  }
}
```

**Node sizing**: `s-2vcpu-4gb` is beautifully readable vs AWS's `t3.medium`.

### Kubernetes Provider for DOKS

```hcl
provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.main.endpoint
  token = digitalocean_kubernetes_cluster.main.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  )
}
```

Simpler than EKS - no IAM exec plugin needed, just token auth.

### Helm Provider for Ingress + cert-manager

```hcl
provider "helm" {
  kubernetes {
    host  = digitalocean_kubernetes_cluster.main.endpoint
    token = digitalocean_kubernetes_cluster.main.kube_config[0].token
    cluster_ca_certificate = base64decode(
      digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
    )
  }
}
```

Used for:
- `ingress-nginx` controller (single LoadBalancer for all apps)
- `cert-manager` (auto TLS via Let's Encrypt)

### GHCR Private Images - imagePullSecrets

GHCR images are private by default. Create a K8s secret:

```bash
kubectl create secret docker-registry ghcr-secret \
  --namespace=missing-table \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USER \
  --docker-password=YOUR_GITHUB_TOKEN  # needs read:packages scope
```

Reference in deployment:

```hcl
spec {
  image_pull_secrets {
    name = "ghcr-secret"
  }
  container {
    image = "ghcr.io/silverbeer/missing-table-backend:latest"
  }
}
```

### Ingress Path-Based Routing

Single domain, multiple services:
- `missingtable.com/` → frontend
- `missingtable.com/api/*` → backend

**Important**: Check if your backend expects `/api` prefix or not!

If backend routes are `/api/auth/login` (prefix included):
```hcl
# Simple prefix matching - no rewrite needed
path {
  path      = "/api"
  path_type = "Prefix"
}
```

If backend routes are `/auth/login` (no prefix):
```hcl
# Rewrite to strip /api prefix
annotations = {
  "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
}
path {
  path      = "/api(/|$)(.*)"
  path_type = "ImplementationSpecific"
}
```

We initially used rewrite but got 404s - backend expected `/api/auth/login`, not `/auth/login`.

### cert-manager + Let's Encrypt

**Install order matters!** CRDs must exist before ClusterIssuer.

1. Install cert-manager via Helm (includes CRDs)
2. Wait for CRDs (`time_sleep` resource)
3. Apply ClusterIssuer

#### HTTP-01 vs DNS-01 Challenge

| Challenge | How it works | IaC-friendly? |
|-----------|--------------|---------------|
| HTTP-01 | Let's Encrypt hits `/.well-known/acme-challenge/*` | No - depends on DNS propagation timing |
| DNS-01 | cert-manager creates TXT record via cloud API | **Yes** - no timing dependency |

**Problem with HTTP-01**: On destroy/rebuild, DNS updates to new IP but Let's Encrypt may still have old IP cached. Challenge fails, requires manual cert deletion.

**Solution**: Use DNS-01 with DigitalOcean API:

```hcl
# Secret for DO API access
resource "kubernetes_secret_v1" "digitalocean_dns" {
  metadata {
    name      = "digitalocean-dns"
    namespace = "cert-manager"
  }
  data = {
    access-token = var.digitalocean_token
  }
}

# ClusterIssuer with DNS-01
resource "kubectl_manifest" "letsencrypt_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-prod-key
        solvers:
          - dns01:
              digitalocean:
                tokenSecretRef:
                  name: digitalocean-dns
                  key: access-token
  YAML
}
```

DNS-01 flow:
1. cert-manager creates `_acme-challenge.missingtable.com` TXT record
2. Let's Encrypt verifies TXT record
3. Certificate issued
4. TXT record cleaned up

No HTTP routing needed, no DNS propagation timing issues.

### DNS as IaC - True 100% IaC

**Problem**: LoadBalancer IPs change on destroy/rebuild. If DNS is separate, you need to manually update the IP.

**Solution**: Manage DNS in the same module, reference ingress IP directly:

```hcl
resource "digitalocean_domain" "missingtable" {
  name = "missingtable.com"
}

resource "digitalocean_record" "root" {
  domain = digitalocean_domain.missingtable.id
  type   = "A"
  name   = "@"
  # Dynamic reference - updates automatically on rebuild!
  value  = data.kubernetes_service_v1.ingress_nginx.status[0].load_balancer[0].ingress[0].ip
  ttl    = 3600
}
```

**Import existing resources:**
```bash
# Get record IDs from DO API
curl -s "https://api.digitalocean.com/v2/domains/DOMAIN/records" \
  -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" | python3 -m json.tool

# Import domain and records
tofu import -var-file=terraform.tfvars digitalocean_domain.missingtable missingtable.com
tofu import -var-file=terraform.tfvars digitalocean_record.root missingtable.com,RECORD_ID
```

**Why this matters**: `tofu destroy && tofu apply` now works with zero manual steps. DNS auto-updates to new IP.

### Nameserver Changes Are Slow

Changing NS records at registrar (Namecheap → DigitalOcean) can take 15 min to 48 hours to propagate globally.

Check propagation:
```bash
dig missingtable.com NS +short         # Which NS is authoritative?
dig missingtable.com @ns1.digitalocean.com +short  # What does DO say?
```

---

## Folder Structure (Updated)

```
clouds/
├── aws/
│   └── environments/dev/     # EKS (Blue Belt - destroyed)
└── digitalocean/
    ├── environments/dev/     # DOKS cluster + app + DNS (100% IaC)
    │   ├── versions.tf       # Providers (do, k8s, helm, kubectl, time)
    │   ├── main.tf           # Cluster, deployments, ingress, cert-manager, DNS
    │   ├── variable.tf       # Secrets (supabase, ghcr, etc)
    │   ├── outputs.tf        # URLs, IPs
    │   └── terraform.tfvars  # Actual secret values (gitignored!)
    └── dns/                  # DEPRECATED - DNS moved to environments/dev

modules/
└── aws/
    ├── vpc/                  # Reusable VPC module
    └── eks/                  # Reusable EKS module
```

**Key insight**: DNS in same module as infrastructure = true 100% IaC. Separate DNS module required manual IP updates on rebuild.

---

## Cost Comparison

| Platform | Control Plane | 2x Nodes | NAT/Network | Total |
|----------|--------------|----------|-------------|-------|
| AWS EKS | $73/mo | $60/mo | $32/mo | **~$165/mo** |
| DO DOKS | **Free** | $48/mo | Included | **~$48/mo** |

---

## Concepts

### Variables & Outputs
- **Variables**: Make resources reusable (avoid hardcoding). Always add sensible defaults.
  - Using type of map(string) for subnet CIDR block makes sense as you need to have nodes running in multiple AZ with EKS
- **Outputs**: Expose key info from resources (e.g., instance ID, IP address after EC2 creation).

### Plan vs Apply
- `plan` = dry run (preview changes)
- `apply` = real run (makes changes)
- **Best practice**: Always run plan before apply. Enforce this in pipelines.

### Providers & Init
- Providers have versions. `~> 5.0` = latest stable 5.x
- Lock file tracks exact version deployed (commit this!)
- AWS provider is large - first `tofu init` takes time

### Modules
- Modules don't need `terraform {}` or `provider {}` blocks - they inherit from caller
- Source paths are relative: `../../../../modules/aws/vpc` from dev environment
- Module outputs must be re-exposed in environment outputs.tf to see them
- `for_each` to create multiple resources from a map
  - `each.key` = the map key (e.g., AZ name)
  - `each.value` = the map value (e.g., CIDR block)
  - Prefer `for_each` over `count` - deleting an item doesn't shift indexes
  - Outputs become maps too: `{ for k, v in aws_subnet.public : k => v.id }`

---

## Patterns & Conventions

### Folder Structure
```
modules/
└── aws/
    ├── vpc/          # VPC, subnets, IGW, NAT, route tables
    └── eks/          # EKS cluster, node groups, IAM roles

clouds/
└── aws/environments/
    ├── dev/          # Calls modules with env-specific config
    ├── staging/
    └── prod/
```
**Why**: Modules are reusable. Environments call modules with different variables.
**Later**: Add gcp/, azure/, digitalocean/ under both.

---

## Cost Warnings

| Resource | Cost | Notes |
|----------|------|-------|
| VPC | Free | No charge for VPC itself |
| NAT Gateway | ~$32/month | No free tier. ALWAYS destroy when not in use. |
| EKS Cluster | ~$72/month | Control plane - $0.10/hour |
| t3.medium | ~$30/month each | Worker nodes - $0.04/hour |

---

## Tips & Gotchas

- `tofu destroy` freely while learning - saves money
- VPCs are free, NAT Gateways are not
- `values()` converts a map to a list - needed when passing subnet IDs to EKS
- Variables with no defaults = required inputs (safety feature)
- EKS needs IAM roles for both cluster AND nodes (separate trust policies)
- Use `_v1` suffix for K8s resources (e.g., `kubernetes_namespace_v1`) - non-v1 is deprecated
- LoadBalancer service type auto-creates cloud LB (ELB on AWS, DO LB on DOKS)
- ELB DNS can take 2-5 min to propagate - test with IP first

## Kubernetes Provider in OpenTofu

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
```

**100% IaC deployment flow:**
1. `kubernetes_namespace_v1` - create namespace
2. `kubernetes_deployment_v1` - deploy pods
3. `kubernetes_service_v1` (type=LoadBalancer) - expose to internet

## Container Registry Decision

| Registry | Cost | Multi-cloud |
|----------|------|-------------|
| Docker Hub | Free (1 private) | ✅ Works everywhere |
| GHCR | Free for public | ✅ Works everywhere |
| ECR | ~$0.10/GB | AWS only |
| GCR | ~$0.026/GB | GCP only |

**Decision**: Use GHCR for multi-cloud. Same image path works on EKS, DOKS, GKE, AKS.

## AWS CLI Commands

```bash
# VPC info
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=missing-table-vpc" --output table

# Subnets in a VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values=VPC_ID" --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch,Tags[?Key==`Name`].Value|[0]]' --output table

# Internet Gateway
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=VPC_ID" --output table

# EKS clusters
aws eks list-clusters

# EKS cluster details
aws eks describe-cluster --name CLUSTER_NAME
```

 ## Future Learning Goals
 - [ ] GitHub Actions Ninja - deep dive on caching, artifacts, matrix builds, reusable workflows

  ## TODO: Coverage Configuration
  - [ ] Move coverage threshold to pyproject.toml [tool.coverage.report]
  - [ ] Current coverage: ~14% (needs work)
  - [ ] Target: 50% initially, then 75%
⏺ ## TODO: GitHub Configuration as IaC
  - [ ] Add GitHub Terraform/OpenTofu provider to platform-bootstrap
  - [ ] Manage repo settings as code (workflow permissions, branch protection)
  - [ ] Manage GHCR package permissions as code
  - [ ] Goal: Zero clicks in GitHub UI for repo configuration


