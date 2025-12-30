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

| Step | Resource | You Write | I Coach |
|------|----------|-----------|---------|
| 1.1 | S3 bucket | `aws_s3_bucket` | Bucket naming, private by default |
| 1.2 | S3 public access block | `aws_s3_bucket_public_access_block` | Why we block everything |
| 1.3 | CloudFront OAC | `aws_cloudfront_origin_access_control` | OAC vs OAI (legacy) |
| 1.4 | S3 bucket policy | `aws_s3_bucket_policy` | Allow CloudFront only |
| 1.5 | ACM certificate | `aws_acm_certificate` | Why us-east-1 for CloudFront |
| 1.6 | Route53 validation | `aws_route53_record` | DNS validation records |
| 1.7 | ACM validation | `aws_acm_certificate_validation` | Wait for validation |
| 1.8 | CloudFront distribution | `aws_cloudfront_distribution` | Origins, behaviors, cache |
| 1.9 | Route53 alias | `aws_route53_record` | Alias to CloudFront |
| 1.10 | S3 lifecycle rule | `aws_s3_bucket_lifecycle_configuration` | Delete runs/* after 30 days |
| 1.11 | Upload placeholder | `aws_s3_object` | index.html with "Coming Soon" |

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

**Goal:** EC2 instance registered as GitHub Actions runner

| Step | Resource | You Write | I Coach |
|------|----------|-----------|---------|
| 2.1 | VPC | `aws_vpc` | CIDR planning, DNS settings |
| 2.2 | Internet Gateway | `aws_internet_gateway` | Required for public subnet |
| 2.3 | Public Subnet | `aws_subnet` | Why public (no NAT = $0) |
| 2.4 | Route Table | `aws_route_table` + association | 0.0.0.0/0 → IGW |
| 2.5 | Security Group | `aws_security_group` | SSH only, egress all |
| 2.6 | IAM Role | `aws_iam_role` | EC2 assume role policy |
| 2.7 | IAM Policy | `aws_iam_role_policy` | S3 write, CloudFront invalidate |
| 2.8 | Instance Profile | `aws_iam_instance_profile` | Attach role to EC2 |
| 2.9 | Key Pair | `aws_key_pair` | For Ansible SSH access |
| 2.10 | EC2 Instance | `aws_instance` | Ubuntu 24.04, t3.small |

**Outputs:**
- `runner_instance_id`
- `runner_public_ip`
- `runner_ssh_command`

**Verification:**
- [ ] `tofu apply` succeeds
- [ ] Can SSH to instance
- [ ] Instance has internet access (can `apt update`)

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

## Cost Estimate

| Resource | Monthly Cost | Notes |
|----------|--------------|-------|
| S3 | ~$0.50 | <1GB storage, minimal requests |
| CloudFront | ~$1.00 | Low traffic, free tier helps |
| Route53 | $0.50 | Hosted zone |
| ACM | Free | Certificates are free |
| EC2 t3.small | ~$15.00 | 2 vCPU, 2GB RAM |
| **Total** | **~$17/month** | Can stop EC2 when not in use |

**Cost optimization:**
- EC2 can be stopped when not running tests
- Consider scheduled start/stop if predictable usage
- Spot instances possible but adds complexity

---

## Security Considerations

1. **S3 Bucket:** Private, only accessible via CloudFront OAC
2. **EC2 Security Group:** SSH restricted to your IP only
3. **IAM Role:** Least privilege - only S3 write to quality bucket
4. **GitHub Runner Token:** Stored in Secrets Manager or passed via user data
5. **SSH Key:** Generated fresh, stored securely

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

## Open Questions

1. **Runner token management:** Store in AWS Secrets Manager? Pass at apply time?
2. **Runner labels:** What labels should the runner have? (`self-hosted`, `ubuntu`, `quality-runner`?)
3. **Concurrency:** Single runner okay for now? (Can add more later)
4. **Runner scope:** Repo-level or org-level runner?

---

## Success Criteria

- [ ] https://quality.missingtable.com loads placeholder page
- [ ] Self-hosted runner visible in GitHub as "Idle"
- [ ] Test workflow runs on self-hosted runner
- [ ] Test results visible at quality.missingtable.com/latest/missing-table/prod/
