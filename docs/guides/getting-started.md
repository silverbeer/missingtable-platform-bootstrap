# Getting Started Guide

Complete step-by-step guide to deploy the infrastructure from scratch.

## Overview

This guide walks you through deploying:
1. AWS infrastructure (Route 53, Lambda, Secrets Manager, S3 state backend)
2. DigitalOcean DOKS cluster with applications
3. TLS certificates via Let's Encrypt
4. External Secrets sync from AWS to Kubernetes

**Estimated time:** 60-90 minutes
**Estimated cost:** ~$49/month (mostly DOKS cluster)

## Prerequisites

Before starting, ensure you have:

### Required Accounts
- ✅ AWS account with admin access
- ✅ DigitalOcean account
- ✅ GitHub account (for container images)
- ✅ Domain registered (we use Route 53, but domain can be registered anywhere)

### Required Tools
- ✅ [OpenTofu](https://opentofu.org/) >= 1.8.0
- ✅ [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- ✅ [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- ✅ [doctl](https://docs.digitalocean.com/reference/doctl/) (DigitalOcean CLI)
- ✅ [Docker](https://www.docker.com/) (for building Lambda image)
- ✅ [gh CLI](https://cli.github.com/) (optional, for easier GitHub operations)

See [prerequisites.md](prerequisites.md) for installation instructions.

### Required Secrets/Credentials

You'll need to gather:
- AWS access key ID and secret access key
- DigitalOcean API token
- GitHub Personal Access Token with `read:packages` scope
- Supabase connection details (if using the example apps)
- Email address for Let's Encrypt notifications

---

## Phase 1: AWS Infrastructure Setup

### 1.1 Configure AWS CLI

```bash
# Verify AWS CLI is configured
aws sts get-caller-identity

# Should show your AWS account ID and user ARN
```

### 1.2 Deploy Terraform State Backend

This creates S3 bucket and DynamoDB table for remote state.

```bash
cd clouds/aws/global/terraform-state

# Initialize OpenTofu
tofu init

# Review what will be created
tofu plan

# Create the backend infrastructure
tofu apply
```

**Resources created:**
- S3 bucket: `missingtable-terraform-state`
- DynamoDB table: `terraform-state-lock`
- Bucket policy and encryption settings

**Cost:** ~$0/month (minimal S3 usage, DynamoDB on-demand)

### 1.3 Deploy Certificate Management Infrastructure

This sets up Lambda + Route 53 for automated Let's Encrypt certificates.

```bash
cd ../certificate-management

# Create terraform.tfvars with your values
cat > terraform.tfvars <<EOF
domain_name         = "your-domain.com"
letsencrypt_email   = "your-email@example.com"
EOF

# Initialize (will configure S3 backend)
tofu init

# Review the plan
tofu plan

# Deploy
tofu apply
```

**Resources created:**
- Route 53 hosted zone for your domain
- Lambda function (certbot) with daily EventBridge trigger
- ECR repository for Lambda Docker image
- Secrets Manager secrets for TLS certificates
- IAM roles and policies

**Important:** Note the Route 53 nameservers from the output:

```bash
tofu output route53_nameservers
```

Update your domain registrar to use these nameservers.

**Cost:** ~$1/month (Route 53 hosted zone) + minimal Lambda execution

### 1.4 Build and Deploy Lambda

The Lambda function needs a Docker image with certbot:

```bash
cd lambda

# Build the Docker image
docker build -t certbot-lambda .

# Get ECR repository URI
ECR_URI=$(aws ecr describe-repositories \
  --repository-names certbot-lambda \
  --region us-east-2 \
  --query 'repositories[0].repositoryUri' \
  --output text)

# Login to ECR
aws ecr get-login-password --region us-east-2 | \
  docker login --username AWS --password-stdin $ECR_URI

# Tag and push
docker tag certbot-lambda:latest $ECR_URI:latest
docker push $ECR_URI:latest

# Update Lambda function code
aws lambda update-function-code \
  --function-name certbot-renewal \
  --image-uri $ECR_URI:latest \
  --region us-east-2
```

**Alternative:** Use the GitHub Actions workflow (after Phase 3).

### 1.5 Test Certificate Generation

Trigger the Lambda manually to generate initial certificates:

```bash
aws lambda invoke \
  --function-name certbot-renewal \
  --region us-east-2 \
  --payload '{"dry_run": false}' \
  /tmp/lambda-response.json

# Check the response
cat /tmp/lambda-response.json
```

Verify certificates in Secrets Manager:

```bash
aws secretsmanager list-secrets --region us-east-2 | grep tls
```

---

## Phase 2: DigitalOcean DOKS Deployment

### 2.1 Configure DigitalOcean CLI

```bash
# Install doctl (if not already installed)
# macOS: brew install doctl
# Linux: snap install doctl

# Authenticate
doctl auth init
# Enter your DigitalOcean API token when prompted

# Verify
doctl account get
```

### 2.2 Prepare Terraform Variables

```bash
cd clouds/digitalocean/environments/dev

# Create terraform.tfvars with ALL required variables
cat > terraform.tfvars <<EOF
# Database connection
database_url = "postgresql://user:pass@host:port/dbname"

# Supabase configuration
supabase_url        = "https://your-project.supabase.co"
supabase_anon_key   = "eyJ..."
supabase_jwt_secret = "your-jwt-secret"

# Let's Encrypt email
letsencrypt_email = "your-email@example.com"

# GitHub Container Registry
ghcr_username = "your-github-username"
ghcr_token    = "ghp_..."  # PAT with read:packages scope

# DigitalOcean
digitalocean_token = "dop_..."

# AWS credentials for External Secrets
aws_access_key_id     = "AKIA..."
aws_secret_access_key = "..."
EOF

# Protect the file
chmod 600 terraform.tfvars
```

**Important:** Never commit `terraform.tfvars` to git! It's already in `.gitignore`.

### 2.3 Deploy DOKS Cluster

```bash
# Initialize with S3 backend
tofu init

# Review the plan
tofu plan

# Deploy (this will take 5-7 minutes)
tofu apply
```

**Resources created:**
- DOKS cluster (2 nodes)
- Kubernetes namespaces (app, ingress-nginx, cert-manager, external-secrets)
- Deployments (frontend, backend)
- Services and Ingress
- Helm releases (nginx-ingress, cert-manager, external-secrets)
- External Secrets sync configuration

**Cost:** ~$48/month (2x s-2vcpu-4gb nodes, control plane free)

### 2.4 Verify Cluster Access

```bash
# Get kubeconfig
doctl kubernetes cluster kubeconfig save missingtable-dev

# Verify connection
kubectl get nodes

# Check pods
kubectl get pods --all-namespaces
```

### 2.5 Wait for Certificate Provisioning

```bash
# Watch certificate status
kubectl get certificate -n missing-table -w

# Check External Secrets sync
kubectl get externalsecret -n missing-table

# Verify TLS secret exists
kubectl get secret missing-table-tls -n missing-table
```

**Troubleshooting:**
- If certificate is stuck in "Pending", check cert-manager logs: `kubectl logs -n cert-manager deployment/cert-manager`
- If External Secret fails, check operator logs: `kubectl logs -n external-secrets deployment/external-secrets`

---

## Phase 3: DNS Configuration

### 3.1 Update Nameservers at Registrar

Point your domain to Route 53 nameservers (from Phase 1.3):

1. Login to your domain registrar (Namecheap, GoDaddy, etc.)
2. Find DNS/Nameserver settings
3. Set custom nameservers to the Route 53 values
4. Save changes

**Note:** DNS propagation can take 15 minutes to 48 hours.

### 3.2 Verify DNS Propagation

```bash
# Check if nameservers have propagated
dig NS your-domain.com +short

# Should show Route 53 nameservers
# ns-xxx.awsdns-xx.com
# ns-xxx.awsdns-xx.net
# ns-xxx.awsdns-xx.org
# ns-xxx.awsdns-xx.co.uk

# Check A records
dig your-domain.com +short
# Should show DOKS LoadBalancer IP
```

### 3.3 Test Application Access

Once DNS propagates:

```bash
# Test HTTP access (should redirect to HTTPS)
curl -I http://your-domain.com

# Test HTTPS access
curl -I https://your-domain.com

# Verify certificate
curl -vI https://your-domain.com 2>&1 | grep "SSL certificate verify"
```

---

## Phase 4: GitHub Actions Setup (Optional)

If you want automated deployments:

### 4.1 Fork or Clone Repository

```bash
gh repo fork silverbeer/missingtable-platform-bootstrap
# or
git clone https://github.com/silverbeer/missingtable-platform-bootstrap.git
cd missingtable-platform-bootstrap
```

### 4.2 Set Up OIDC (Recommended)

Create IAM role for GitHub Actions:

```bash
# The repository includes the GitHubActions-Terraform role setup
# Update the trust policy to include your GitHub username and repo

# Get the role ARN
aws iam get-role --role-name GitHubActions-Terraform \
  --query 'Role.Arn' --output text
```

### 4.3 Add GitHub Secrets

```bash
# Using gh CLI
gh secret set AWS_OIDC_ROLE_ARN --body "arn:aws:iam::YOUR-ACCOUNT:role/GitHubActions-Terraform"
gh secret set DIGITALOCEAN_TOKEN --body "dop_..."
gh secret set TF_VAR_DATABASE_URL --body "postgresql://..."
gh secret set TF_VAR_SUPABASE_URL --body "https://..."
gh secret set TF_VAR_SUPABASE_ANON_KEY --body "eyJ..."
gh secret set TF_VAR_SUPABASE_JWT_SECRET --body "..."
gh secret set TF_VAR_LETSENCRYPT_EMAIL --body "your-email@example.com"
gh secret set TF_VAR_GHCR_USERNAME --body "your-username"
gh secret set TF_VAR_GHCR_TOKEN --body "ghp_..."
gh secret set TF_VAR_AWS_ACCESS_KEY_ID --body "AKIA..."
gh secret set TF_VAR_AWS_SECRET_ACCESS_KEY --body "..."
```

### 4.4 Test Workflows

```bash
# Trigger infrastructure plan
gh workflow run k8s-infra-pipeline.yml \
  -f command=plan \
  -f cloud=digitalocean \
  -f environment=dev

# Watch the run
gh run watch
```

---

## Verification Checklist

Before considering the setup complete, verify:

- [ ] AWS S3 bucket and DynamoDB table exist
- [ ] Route 53 hosted zone created with correct nameservers
- [ ] Lambda function deployed and tested successfully
- [ ] Certificates exist in AWS Secrets Manager
- [ ] Certificates imported to ACM
- [ ] DOKS cluster running with 2 nodes
- [ ] All pods in Running state (`kubectl get pods -A`)
- [ ] Ingress has external IP (`kubectl get ing -A`)
- [ ] DNS points to LoadBalancer IP
- [ ] HTTPS works with valid Let's Encrypt certificate
- [ ] Applications are accessible
- [ ] GitHub Actions workflows configured (if using)

---

## Cost Management

### Total Monthly Cost: ~$49

Breakdown:
- DOKS Cluster: $48/month
- Route 53 (2 hosted zones): $1/month
- Lambda executions: ~$0 (free tier)
- S3 state storage: ~$0 (minimal)
- Secrets Manager: ~$0 (2 secrets, $0.40/month)

### Reducing Costs

**Development/Learning:**
```bash
# Destroy DOKS cluster when not in use
cd clouds/digitalocean/environments/dev
tofu destroy

# Keep AWS infrastructure (minimal cost)
```

**Complete Teardown:**
```bash
# Destroy DOKS
cd clouds/digitalocean/environments/dev
tofu destroy

# Destroy certificate management
cd ../../../aws/global/certificate-management
tofu destroy

# Destroy state backend (do this last!)
cd ../terraform-state
tofu destroy
```

---

## Troubleshooting

### Common Issues

**Issue:** Certificate stuck in "Pending"
**Solution:** Check cert-manager logs, verify Route 53 permissions

**Issue:** External Secrets not syncing
**Solution:** Verify AWS credentials in K8s secret, check operator logs

**Issue:** DNS not resolving
**Solution:** Nameserver propagation takes time, check with `dig` command

**Issue:** Lambda deployment fails
**Solution:** Check ECR image exists, verify IAM permissions

**Issue:** OpenTofu state lock error
**Solution:** Manually delete lock from DynamoDB table

See [troubleshooting.md](troubleshooting.md) for detailed solutions.

---

## Next Steps

After successful deployment:

1. **Enable branch protection** - See [github-branch-protection.md](github-branch-protection.md)
2. **Customize applications** - Update deployments with your own images
3. **Add more domains** - Extend certificate management for additional sites
4. **Multi-cloud expansion** - Deploy to GKE, AKS for true multi-cloud
5. **Monitoring** - Add Prometheus, Grafana for observability
6. **Cost optimization** - Review and optimize node sizes

---

## Getting Help

- **Issues:** Check [troubleshooting.md](troubleshooting.md)
- **Questions:** Open a GitHub issue
- **Documentation:** See [docs/](../README.md) for all guides
- **Decisions:** Review [decisions-log.md](../decisions-log.md) for context

Happy deploying! 🚀
