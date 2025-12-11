# missingtable-platform-bootstrap

Multi-cloud Kubernetes infrastructure as code (IaC) learning journey, deploying real applications across multiple cloud providers using OpenTofu and Kubernetes.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.8.0-blue)](https://opentofu.org/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32-blue)](https://kubernetes.io/)

## What is this?

A **production-grade learning project** that demonstrates:
- Multi-cloud Kubernetes deployments (AWS, DigitalOcean, and more)
- Infrastructure as Code with OpenTofu (open-source Terraform fork)
- Automated certificate management with Let's Encrypt
- CI/CD pipelines with GitHub Actions
- Remote state management with S3 + DynamoDB
- OIDC authentication for secure deployments

This repository manages infrastructure for two production domains:
- **missingtable.com** - Table reservation application
- **qualityplaybook.dev** - Software quality resources

## What's Deployed

**DigitalOcean DOKS (Production):**
- ✅ Kubernetes cluster (2 nodes, $48/month)
- ✅ Application deployments (frontend + backend)
- ✅ Ingress with TLS certificates
- ✅ External Secrets sync from AWS
- ✅ DNS managed via Route 53

**AWS (Global Services):**
- ✅ Lambda-based certificate management (certbot + Route 53 DNS-01)
- ✅ Secrets Manager for TLS certificates
- ✅ ACM certificate import for EKS compatibility
- ✅ S3 + DynamoDB for Terraform state
- ✅ OIDC identity provider for GitHub Actions

**CI/CD Pipelines:**
- ✅ Automated Lambda deployment on merge to main
- ✅ Manual infrastructure workflow (tofu plan/apply/destroy)
- ✅ OIDC authentication (no static credentials)
- ✅ Branch protection on main

## Quick Start

### Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.8.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [AWS CLI](https://aws.amazon.com/cli/) configured
- [doctl](https://docs.digitalocean.com/reference/doctl/) (for DigitalOcean)
- AWS account with Route 53 hosted zone
- DigitalOcean account

### Deploy DOKS Environment

```bash
# Clone the repository
git clone https://github.com/silverbeer/missingtable-platform-bootstrap.git
cd missingtable-platform-bootstrap

# Configure variables
cd clouds/digitalocean/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
tofu init
tofu plan
tofu apply
```

See [Getting Started Guide](docs/guides/getting-started.md) for detailed instructions.

## Architecture

### Certificate Management Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Account                          │
│                                                               │
│  ┌─────────────┐      ┌──────────────┐      ┌─────────────┐│
│  │ EventBridge │─────▶│ Lambda       │─────▶│  Secrets    ││
│  │ Daily Cron  │      │ + certbot    │      │  Manager    ││
│  └─────────────┘      └──────────────┘      └─────────────┘│
│                              │                      │        │
│                              │                      │        │
│                              ▼                      │        │
│                       ┌──────────────┐             │        │
│                       │  Route 53    │             │        │
│                       │  DNS-01      │             │        │
│                       │  Validation  │             │        │
│                       └──────────────┘             │        │
│                              │                      │        │
│                              ▼                      ▼        │
│                       ┌──────────────┐      ┌─────────────┐│
│                       │     ACM      │      │   External  ││
│                       │ (for EKS)    │      │   Secrets   ││
│                       └──────────────┘      └─────────────┘│
└────────────────────────────────────────────────────┼────────┘
                                                       │
                                                       │ Syncs to K8s
                                                       ▼
                                       ┌─────────────────────────┐
                                       │  DOKS Cluster           │
                                       │  ┌─────────────────┐    │
                                       │  │ TLS Secrets     │    │
                                       │  │ (auto-renewed)  │    │
                                       │  └─────────────────┘    │
                                       └─────────────────────────┘
```

Certificates are automatically:
- Generated via Let's Encrypt with certbot
- Validated using Route 53 DNS-01 challenge
- Stored in AWS Secrets Manager
- Imported to ACM for EKS Load Balancers
- Synced to DOKS via External Secrets Operator
- Renewed daily (90-day certs, checked daily)

## Repository Structure

```
.
├── .github/workflows/       # CI/CD pipelines
│   ├── k8s-infra-pipeline.yml         # Manual tofu plan/apply/destroy
│   └── lambda-certbot-deploy.yml      # Auto-deploy Lambda on merge
├── clouds/
│   ├── aws/
│   │   └── global/
│   │       ├── terraform-state/        # S3 + DynamoDB backend
│   │       └── certificate-management/ # Lambda + Route53 + Secrets
│   └── digitalocean/
│       └── environments/dev/           # DOKS cluster + apps + ingress
├── docs/
│   ├── decisions-log.md                # Learning journal
│   ├── guides/                         # How-to guides
│   └── architecture/                   # System design docs
├── scripts/                            # Helper automation
├── LICENSE                             # MIT License
└── README.md                           # This file
```

## Cost Breakdown

| Service | Monthly Cost | Notes |
|---------|--------------|-------|
| DOKS Cluster | $48 | 2x s-2vcpu-4gb nodes (control plane free!) |
| Lambda (certbot) | ~$0 | Free tier sufficient |
| S3 (state) | ~$0 | Minimal usage |
| Route 53 | ~$1 | 2 hosted zones |
| **Total** | **~$49/month** | 70% cheaper than EKS! |

For comparison: AWS EKS would cost ~$165/month ($73 control plane + $60 nodes + $32 NAT Gateway).

## Key Technologies

- **IaC:** OpenTofu 1.8.0 (open-source Terraform fork)
- **Orchestration:** Kubernetes 1.32
- **Certificate Management:** Let's Encrypt + certbot + Route 53
- **Secret Management:** AWS Secrets Manager + External Secrets Operator
- **State Backend:** S3 + DynamoDB with locking
- **CI/CD:** GitHub Actions with OIDC authentication
- **DNS:** AWS Route 53
- **Container Registry:** GitHub Container Registry (GHCR)

## Key Learnings

See [decisions-log.md](docs/decisions-log.md) for detailed technical decisions and lessons learned, including:

- Why DOKS is dramatically simpler than EKS (1 resource vs ~15)
- DNS-01 challenge vs HTTP-01 for certificate validation
- Remote state management for CI/CD
- OIDC authentication vs static credentials
- Multi-domain certificate management strategies

## Documentation

- [Getting Started Guide](docs/guides/getting-started.md) - Step-by-step setup
- [Prerequisites](docs/guides/prerequisites.md) - Required tools and accounts
- [Architecture Overview](docs/architecture/overview.md) - System design
- [Branch Protection Setup](docs/guides/github-branch-protection.md) - Repository configuration
- [Workflow Discipline](docs/guides/workflow-discipline.md) - Development workflow
- [Decisions Log](docs/decisions-log.md) - Technical decisions and learning

## CI/CD Workflows

### Lambda Deployment (Automatic)
Triggers on merge to `main` when Lambda code changes:
- Builds Docker image
- Pushes to ECR with `:latest` and `:sha` tags
- Updates both Lambda functions
- Tests with dry-run invocation

### Infrastructure Deployment (Manual)
Triggered via `workflow_dispatch` with options:
- `tofu plan` - Preview changes
- `tofu apply` - Apply infrastructure changes
- `tofu destroy` - Tear down resources

Both workflows use OIDC for secure, temporary AWS credentials.

## Contributing

This is a personal learning project, but issues and suggestions are welcome! See [workflow-discipline.md](docs/guides/workflow-discipline.md) for development workflow.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

A learning project demonstrating multi-cloud Infrastructure as Code with real production workloads.

Built with assistance from Claude Code - an AI pair programmer that emphasizes learning over shortcuts.
