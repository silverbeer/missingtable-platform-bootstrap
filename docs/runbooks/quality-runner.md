# Quality Site Runner Management

## Overview

The quality site (`quality.missingtable.com`) includes a self-hosted GitHub Actions runner for running tests and publishing results. The runner is an EC2 instance that **costs ~$15/month when running**.

**Important:** This runner is for learning purposes. Keep it OFF when not actively using it.

## Quick Reference

```bash
# Check if runner is on or off
./scripts/quality-runner.sh status

# Start the runner (~$15/mo while running)
./scripts/quality-runner.sh up

# Stop the runner (saves money)
./scripts/quality-runner.sh down
```

## Cost Breakdown

| Component | Monthly Cost | Always On? |
|-----------|--------------|------------|
| S3 bucket | ~$0.02 | Yes (free tier) |
| CloudFront | ~$0.00 | Yes (free tier) |
| Route53 | $0.50 | Yes |
| ACM cert | Free | Yes |
| Secrets Manager | ~$0.40 | Yes |
| VPC/Subnet/IGW | Free | Yes |
| **EC2 runner** | **~$15.00** | **NO - turn off!** |

## When to Use the Runner

1. **Learning Ansible** - Configure the runner with Ansible playbooks
2. **Testing CI/CD** - Test GitHub Actions workflows on self-hosted runner
3. **Publishing reports** - Upload test results to quality.missingtable.com

## Workflow

### Starting a Session

```bash
# 1. Check current status
./scripts/quality-runner.sh status

# 2. Start the runner if needed
./scripts/quality-runner.sh up

# 3. Wait for it to be ready (check GitHub repo settings)
# Settings → Actions → Runners → should show "Idle"
```

### Ending a Session

```bash
# ALWAYS shut down when done
./scripts/quality-runner.sh down
```

## Terraform Details

The runner is controlled by a variable:

```hcl
variable "runner_enabled" {
  default = false  # OFF by default
}
```

The script wraps these commands:
- `up` → `tofu apply -var="runner_enabled=true"`
- `down` → `tofu apply -var="runner_enabled=false" -auto-approve`

## Troubleshooting

### Runner not appearing in GitHub

1. Check EC2 is running: `./scripts/quality-runner.sh status`
2. SSH to instance and check runner service
3. Verify runner token in Secrets Manager is valid (tokens expire in 1 hour)

### Can't SSH to runner

1. Check your IP in `terraform.tfvars` matches current IP
2. Update `allowed_ssh_cidr` if IP changed
3. Run `tofu apply` to update security group

## Files

| File | Purpose |
|------|---------|
| `scripts/quality-runner.sh` | Management script |
| `clouds/aws/global/quality-site/main.tf` | Infrastructure (EC2, VPC, IAM) |
| `clouds/aws/global/quality-site/terraform.tfvars` | Your variables (gitignored) |
| `clouds/aws/global/quality-site/terraform.tfvars.example` | Example variables |
