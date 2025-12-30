# Quality Site Implementation Plan

## Overview

Build `quality.missingtable.com` - a public site showcasing test results, coverage reports, and quality metrics for the MissingTable project.

**Learning Goals:**
- Hands-on OpenTofu for all AWS resources
- Meaningful Ansible use (self-hosted GitHub runner configuration)
- Production-ready static site hosting pattern

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           GitHub Actions                                 │
│  ┌─────────────────┐    ┌─────────────────────────────────────────────┐ │
│  │ missing-table   │    │ Self-Hosted Runner (EC2)                    │ │
│  │ repo workflow   │───▶│ - Docker, Python, Node                      │ │
│  │                 │    │ - Runs tests, generates reports             │ │
│  └─────────────────┘    │ - Uploads to S3                             │ │
│                         └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS                                         │
│                                                                          │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────────────┐ │
│  │   Route 53   │────▶│  CloudFront  │────▶│  S3 Bucket (private)     │ │
│  │              │     │  (OAC)       │     │                          │ │
│  │ quality.     │     │              │     │  latest/<repo>/          │ │
│  │ missingtable │     │  us-east-1   │     │  runs/<repo>/<date>/     │ │
│  │ .com         │     │  ACM cert    │     │                          │ │
│  └──────────────┘     └──────────────┘     └──────────────────────────┘ │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────┐│
│  │  EC2 (Self-Hosted Runner)          VPC (quality-site-vpc)           ││
│  │  ┌────────────────────────────┐    ┌───────────────────────────┐    ││
│  │  │ t3.small (Ubuntu 24.04)   │    │ Public Subnet             │    ││
│  │  │ - GitHub Actions runner   │◀───│ - Internet Gateway        │    ││
│  │  │ - Docker                  │    │ - Security Group (SSH)    │    ││
│  │  │ - Python (uv)             │    └───────────────────────────┘    ││
│  │  │ - Node.js                 │                                      ││
│  │  │ - Playwright deps         │    IAM Role:                         ││
│  │  └────────────────────────────┘    - S3 write to quality bucket     ││
│  │                                     - CloudFront invalidation        ││
│  └──────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

---

## S3 Path Contract (from Master Plan)

```
quality.missingtable.com/
├── index.html                              # Landing page with links
├── latest/
│   └── missing-table/
│       └── prod/
│           ├── backend-unit/               # pytest HTML + coverage
│           ├── frontend-unit/              # vitest coverage
│           ├── api-allure/                 # Allure report
│           ├── api-bruno/                  # Bruno HTML
│           ├── e2e-playwright/             # Playwright HTML
│           └── summary.json                # Aggregated metrics
└── runs/
    └── missing-table/
        └── prod/
            └── 2025-01-15/
                └── <run-id>/               # Same structure as latest/
```

---

## Implementation Phases

### Phase 1: Static Site Infrastructure (This Repo)

**Goal:** `quality.missingtable.com` serves a placeholder page

| Step | Resource | Status | Notes |
|------|----------|--------|-------|
| 1.1 | S3 bucket | ✅ Done | `aws_s3_bucket.quality_site` |
| 1.2 | S3 public access block | ✅ Done | `aws_s3_bucket_public_access_block.quality_site_public_block` |
| 1.3 | CloudFront OAC | ✅ Done | `aws_cloudfront_origin_access_control.quality_site_cdn_oac` |
| 1.4 | S3 bucket policy | ✅ Done | `aws_s3_bucket_policy.quality_site_policy` |
| 1.5 | ACM certificate | ✅ Done | `aws_acm_certificate.quality_site_cert` (us-east-1) |
| 1.6 | Route53 validation | ✅ Done | `aws_route53_record.quality_site_cert_validation` |
| 1.7 | ACM validation | 🔄 Next | `aws_acm_certificate_validation` - wait for validation |
| 1.8 | CloudFront distribution | ⬜ Pending | `aws_cloudfront_distribution` |
| 1.9 | Route53 alias | ⬜ Pending | `aws_route53_record` (alias to CloudFront) |
| 1.10 | S3 lifecycle rule | ⬜ Pending | `aws_s3_bucket_lifecycle_configuration` |
| 1.11 | Upload placeholder | ⬜ Pending | `aws_s3_object` (index.html) |

**Outputs:**
- `quality_site_bucket_name`
- `quality_site_bucket_arn`
- `quality_site_cloudfront_distribution_id`
- `quality_site_cloudfront_domain`
- `quality_site_url` (https://quality.missingtable.com)

**Verification:**
- [ ] `tofu apply` succeeds
- [ ] https://quality.missingtable.com shows placeholder
- [ ] HTTP redirects to HTTPS
- [ ] Direct S3 URL returns 403 (access denied)

---

### Phase 2: Self-Hosted GitHub Runner (This Repo)

**Goal:** EC2 instance ready for Ansible configuration

**Cost Warning:** Phase 2 creates an EC2 instance (~$15/mo). Destroy when not in use!

| Step | Resource | You Write | I Coach |
|------|----------|-----------|---------|
| 2.1 | VPC | `aws_vpc` | CIDR planning, DNS settings |
| 2.2 | Internet Gateway | `aws_internet_gateway` | Required for public subnet |
| 2.3 | Public Subnet | `aws_subnet` | Why public (no NAT = $0) |
| 2.4 | Route Table | `aws_route_table` + association | 0.0.0.0/0 → IGW |
| 2.5 | Security Group | `aws_security_group` | SSH only, egress all |
| 2.6 | Secrets Manager | `aws_secretsmanager_secret` | For GitHub runner token |
| 2.7 | IAM Role | `aws_iam_role` | EC2 assume role policy |
| 2.8 | IAM Policy | `aws_iam_role_policy` | S3 write, CloudFront invalidate, Secrets read |
| 2.9 | Instance Profile | `aws_iam_instance_profile` | Attach role to EC2 |
| 2.10 | Key Pair | `aws_key_pair` | For Ansible SSH access |
| 2.11 | EC2 Instance | `aws_instance` | Ubuntu 24.04, t3.small |

**Outputs:**
- `runner_instance_id`
- `runner_public_ip`
- `runner_ssh_command`
- `runner_token_secret_arn`

**Verification:**
- [ ] `tofu apply` succeeds
- [ ] Can SSH to instance
- [ ] Instance has internet access (can `apt update`)
- [ ] **REMINDER: Destroy EC2 when done testing Phase 2!**

---

### Phase 3: Ansible Runner Configuration (This Repo)

**Goal:** EC2 configured as production GitHub runner

| Step | Task | You Write | I Coach |
|------|------|-----------|---------|
| 3.1 | Inventory | Dynamic inventory from Terraform output | How to wire tofu → ansible |
| 3.2 | Base role | `roles/github-runner/tasks/main.yml` | Apt packages, users |
| 3.3 | Docker install | Docker CE installation tasks | Official Docker repo |
| 3.4 | Python setup | uv + Python 3.12 | Your custom uv modules! |
| 3.5 | Node.js setup | Node 20 LTS via nodesource | For Playwright |
| 3.6 | Playwright deps | System dependencies | `npx playwright install-deps` |
| 3.7 | Runner agent | GitHub Actions runner install | Runner token handling |
| 3.8 | Runner service | systemd service configuration | Auto-start on boot |

**Verification:**
- [ ] `ansible-playbook` runs without errors
- [ ] Runner appears in GitHub repo settings
- [ ] Runner shows as "Idle"

---

### Phase 4: Test Publishing Workflow (missing-table Repo)

**Goal:** Tests run on self-hosted runner, results published

| Step | Task | Location |
|------|------|----------|
| 4.1 | Backend pytest workflow | `.github/workflows/quality-backend.yml` |
| 4.2 | Allure report generation | pytest-allure plugin config |
| 4.3 | S3 upload step | `aws s3 sync` to quality bucket |
| 4.4 | CloudFront invalidation | `aws cloudfront create-invalidation` |
| 4.5 | Summary.json generation | Python script for metrics |
| 4.6 | Index.html generation | Script to create landing page |

**Note:** Phase 4 is in the `missing-table` repo, not this one.

---

## File Structure

```
clouds/aws/global/quality-site/
├── backend.tf              # S3 remote state
├── versions.tf             # OpenTofu + provider versions
├── providers.tf            # AWS provider (us-east-2 + us-east-1 alias)
├── main.tf                 # All resources (or split by concern)
├── variables.tf            # Input variables
├── outputs.tf              # Output values
└── placeholder/
    └── index.html          # Placeholder page content

ansible/
├── ansible.cfg             # Ansible configuration
├── inventory/
│   └── quality-runner.yml  # Dynamic or static inventory
├── playbooks/
│   └── configure-runner.yml
└── roles/
    └── github-runner/
        ├── tasks/
        │   └── main.yml
        ├── handlers/
        │   └── main.yml
        ├── templates/
        │   ├── runner.service.j2
        │   └── .env.j2
        └── vars/
            └── main.yml
```

---

## Cost Management (IMPORTANT)

### Cost Breakdown

| Resource | Monthly Cost | Free Tier? | Notes |
|----------|--------------|------------|-------|
| S3 | ~$0.02 | YES (5GB) | <1GB storage, minimal requests |
| CloudFront | ~$0.00 | YES (1TB/mo) | Low traffic, well within free tier |
| Route53 | $0.50 | NO | Hosted zone fee (unavoidable) |
| ACM | Free | YES | Certificates are always free |
| Secrets Manager | ~$0.40 | NO | $0.40/secret/month + API calls |
| **Phase 1 Total** | **~$1/month** | | Static site only |
| EC2 t3.small | ~$15/month | NO | **Only when running** |
| **With EC2 running** | **~$16/month** | | |

### EC2 Cost Control

**The EC2 instance is the primary cost driver.** It should be OFF by default.

```bash
# Spin UP the runner (when you need to run tests)
cd /path/to/clouds/aws/global/quality-site
tofu apply -target=aws_instance.github_runner

# Spin DOWN the runner (when done - DO THIS!)
tofu apply -target=aws_instance.github_runner -var="runner_enabled=false"
# OR destroy just the instance:
tofu destroy -target=aws_instance.github_runner
```

**Alternative: AWS CLI stop/start (preserves instance, ~$1.50/mo for EBS)**
```bash
# Stop (keeps EBS volume, stops compute charges)
aws ec2 stop-instances --instance-ids <instance-id> --region us-east-2

# Start (when ready to use)
aws ec2 start-instances --instance-ids <instance-id> --region us-east-2
```

### Cost Checkpoints

I will remind you at these points:
- [ ] After Phase 1 apply: "Phase 1 complete. Monthly cost: ~$1. No EC2 yet."
- [ ] After Phase 2 apply: "EC2 is now running (~$15/mo). Destroy when done testing."
- [ ] After any test run: "Tests complete. Remember to stop/destroy the EC2 instance."

### What's Safe to Leave Running

| Resource | Safe to Leave? | Why |
|----------|----------------|-----|
| S3 bucket | YES | Pennies, free tier covers it |
| CloudFront | YES | Free tier, no minimum |
| Route53 | YES | $0.50/mo fixed, can't avoid |
| ACM cert | YES | Free |
| Secrets Manager | YES | $0.40/mo, negligible |
| **EC2 instance** | **NO** | **$15/mo - destroy when not in use** |
| VPC/Subnet/IGW | YES | Free (no NAT Gateway) |

---

## Security Considerations

1. **S3 Bucket:** Private, only accessible via CloudFront OAC
2. **EC2 Security Group:** SSH restricted to your IP only
3. **IAM Role:** Least privilege - only S3 write to quality bucket + CloudFront invalidate
4. **GitHub Runner Token:** Stored in AWS Secrets Manager, retrieved by Ansible at configure time
5. **SSH Key:** Generated fresh for this project (`~/.ssh/quality-runner`)
6. **Secrets Manager Access:** EC2 IAM role includes `secretsmanager:GetSecretValue` for runner token only

---

## Why Ansible Makes Sense Here

| Without Ansible | With Ansible |
|-----------------|--------------|
| User data script (hard to test) | Idempotent playbook (easy to re-run) |
| SSH + manual commands | Documented, version-controlled config |
| No visibility into state | Clear role structure shows what's installed |
| Hard to update | Change playbook, re-run |

**Real-world pattern:** Terraform creates the instance, Ansible configures it. This is the standard split in production environments.

---

## Decisions Made

| Question | Decision |
|----------|----------|
| Runner token management | AWS Secrets Manager |
| Runner labels | `self-hosted`, `linux`, `x64`, `quality-runner` |
| Concurrency | Single runner (can scale later) |
| Runner scope | Repo-level (`missing-table` only) |
| EC2 lifecycle | **Off by default** - spin up only when running tests |

---

## Success Criteria

- [ ] https://quality.missingtable.com loads placeholder page
- [ ] Self-hosted runner visible in GitHub as "Idle"
- [ ] Test workflow runs on self-hosted runner
- [ ] Test results visible at quality.missingtable.com/latest/missing-table/prod/
