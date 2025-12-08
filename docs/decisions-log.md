# Decisions & Learning Log

Quick notes captured during OpenTofu ninja training. Will be formalized later.

---

## DigitalOcean (Blue Belt → Brown Belt)

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

Uses nginx-ingress rewrite annotation:
```hcl
annotations = {
  "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
}
```

Path regex: `/api(/|$)(.*)` captures everything after `/api` and rewrites to `/$2`.

### cert-manager + Let's Encrypt

**Install order matters!** CRDs must exist before ClusterIssuer.

1. Install cert-manager via Helm (includes CRDs)
2. Apply ClusterIssuer separately (after Helm release completes)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

Certificate auto-issues once DNS points to ingress IP.

### DNS as IaC

Managing DNS in DigitalOcean via OpenTofu:

```hcl
variable "domains" {
  type = map(object({
    records = list(object({
      type  = string
      name  = string
      value = string
      ttl   = optional(number, 3600)
    }))
  }))
}

resource "digitalocean_domain" "domains" {
  for_each = var.domains
  name     = each.key
}
```

**Import existing resources:**
```bash
tofu import 'digitalocean_domain.domains["missingtable.com"]' missingtable.com
tofu import 'digitalocean_record.records["missingtable.com-A-@-161.35.252.192"]' missingtable.com,RECORD_ID
```

Get record IDs via DO API:
```bash
curl -s "https://api.digitalocean.com/v2/domains/DOMAIN/records" \
  -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" | python3 -m json.tool
```

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
    ├── environments/dev/     # DOKS cluster + app deployment
    │   ├── versions.tf       # Providers (do, k8s, helm)
    │   ├── main.tf           # Cluster, deployments, ingress, cert-manager
    │   ├── variable.tf       # Secrets (supabase, etc)
    │   ├── outputs.tf        # URLs, IPs
    │   ├── terraform.tfvars  # Actual secret values (gitignored!)
    │   └── cluster-issuer.yaml  # Applied after cert-manager
    └── dns/                  # DNS for all domains
        ├── versions.tf
        ├── main.tf           # Domain + record resources
        ├── variables.tf      # Domain schema
        ├── outputs.tf
        └── terraform.tfvars  # Domain configs

modules/
└── aws/
    ├── vpc/                  # Reusable VPC module
    └── eks/                  # Reusable EKS module
```

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


