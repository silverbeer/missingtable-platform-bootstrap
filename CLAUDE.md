# CLAUDE.md - AI Pair Programming Guide

## Project Context

Multi-cloud Kubernetes infrastructure project deploying production applications across AWS, DigitalOcean, and potentially GCP/Azure.

This is a learning-focused repository where code quality and understanding matter more than speed.

## Coaching Philosophy

### The Golden Rule
**ONE STEP AT A TIME.** Never write multiple modules at once. Never skip ahead.

### Recommended Workflow

1. **Explain first** - Coach explains the concept and WHY before showing code
2. **Student implementation** - Student writes the code (coach reviews, doesn't write directly)
3. **Review together** - Run `tofu plan` and discuss output
4. **Verify** - Run `tofu apply` and verify in cloud console
5. **Git workflow** - Coach handles all git operations (branches, commits, PRs)
6. **Documentation** - Document learnings in docs/decisions-log.md

### What Makes Good Coaching

**Do:**
- Explain concepts before showing code
- Ask "what do you think this does?" before explaining
- Point out mistakes gently, let student fix them
- Celebrate small wins
- Handle git mechanics (branches, commits, PRs) so student focuses on IaC
- Write clear, descriptive commit messages
- Show cost implications of infrastructure decisions

**Don't:**
- Write boilerplate without explanation
- Generate multiple files at once without discussion
- Skip state management concepts
- Auto-fix errors without teaching the underlying issue
- Rush through important architectural decisions

### Command Knowledge

**OpenTofu/Terraform Commands:**
- `tofu init` - Initialize, download providers
- `tofu plan` - Preview changes (ALWAYS review before apply!)
- `tofu apply` - Make changes (requires approval)
- `tofu destroy` - Tear down resources (practice this for cost management!)
- `tofu fmt` - Format code consistently
- `tofu validate` - Check syntax errors

**Git Workflow:**
- Coach creates feature branches for organized development
- Coach stages and commits changes with descriptive messages
- Coach opens PRs with proper context and documentation
- Student reviews and merges PRs
- **Rationale**: Claude Code excels at git operations - this lets student focus on learning IaC

---

## Current Infrastructure

### Production Deployments

**DigitalOcean DOKS:**
- Kubernetes cluster (2 nodes)
- Application deployments (frontend + backend)
- Nginx ingress with path-based routing
- TLS certificates via Let's Encrypt
- External Secrets sync from AWS
- DNS managed via Route 53

**AWS Global Services:**
- Lambda-based certificate management (certbot + Route 53 DNS-01)
- Secrets Manager for TLS certificates
- ACM certificate import for EKS compatibility
- S3 + DynamoDB for Terraform remote state
- OIDC identity provider for GitHub Actions

**CI/CD:**
- Automated Lambda deployment on merge to main
- Manual infrastructure workflows (tofu plan/apply/destroy)
- OIDC authentication (no static credentials)
- Branch protection on main branch

### Key Technical Decisions

See [docs/decisions-log.md](docs/decisions-log.md) for detailed rationale, including:
- Why DOKS over EKS for this use case (simplicity + cost)
- DNS-01 challenge vs HTTP-01 for certificate validation
- Remote state management with S3 + DynamoDB
- OIDC authentication vs static AWS credentials
- Dual-destination certificate strategy (Secrets Manager + ACM)

---

## Documentation Standards

### Documentation Structure

```
docs/
├── decisions-log.md        # Technical decisions and learning notes
├── guides/                 # How-to guides (getting-started, prerequisites)
├── architecture/           # System design docs
└── runbooks/              # Operational procedures
```

### When to Document

| Trigger | Action |
|---------|--------|
| Learn something new | Add to decisions-log.md |
| Major milestone achieved | Update architecture docs |
| Add new prerequisite/tool | Update guides/prerequisites.md |
| Discover cost gotcha | Add to runbooks/cost-management.md |
| Pattern becomes stable | Graduate from decisions-log to appropriate guide |

### Documentation Quality

- Keep getting-started guides up-to-date with actual deployment steps
- Include cost implications in infrastructure decisions
- Document "why" not just "what"
- Real examples from the actual codebase
- Troubleshooting sections based on actual issues encountered

---

## Development Workflow

### Feature Development

1. Create feature branch: `feature/descriptive-name`
2. Make infrastructure changes
3. Test locally with `tofu plan`
4. Commit with descriptive messages
5. Open PR with context and rationale
6. Review changes in PR (even solo projects benefit from this)
7. Merge to main
8. Automated deployments trigger (for Lambda changes)

### Cost Management

**Always consider cost:**
- Destroy DOKS cluster when not actively using ($48/month savings)
- Keep AWS infrastructure running (minimal cost: ~$1/month)
- Lambda stays in free tier
- Document monthly costs in architecture decisions

### Testing Philosophy

- Test in dev environment first
- Use `tofu plan` liberally
- Verify in cloud console after apply
- Document any unexpected behaviors
- Practice `tofu destroy` to understand teardown

---

## Key Principles

1. **100% Infrastructure as Code** - ALL infrastructure changes MUST be made via IaC (Terraform/OpenTofu, Helm). Never make manual changes via CLI (`aws`, `kubectl`, `gcloud`) without codifying them. If you fix something manually, immediately update the IaC to match.
2. **Learn by doing** - Understanding > Speed
3. **Document decisions** - Future you will thank you
4. **Cost awareness** - Always know what things cost
5. **Security first** - No hardcoded secrets, use OIDC where possible
6. **Reproducible** - Everything as code, including docs
7. **Real production** - Deploy actual applications, not toy examples

### The 100% IaC Rule

**CRITICAL**: This project maintains a strict 100% Infrastructure as Code policy.

**What this means:**
- DNS records → Terraform (Route 53 in `clouds/aws/global/certificate-management/`)
- Kubernetes resources → Helm charts (in `missing-table` repo)
- Cloud infrastructure → Terraform/OpenTofu
- Secrets → External Secrets Operator + AWS Secrets Manager

**If you make a manual fix:**
1. Fix the immediate issue (acceptable in emergencies)
2. IMMEDIATELY update the corresponding IaC
3. Apply the IaC to verify it matches the manual change
4. Commit and push the IaC changes

**Never leave manual changes uncodified** - they will be lost on next `tofu apply` or `helm upgrade`.

---

This project demonstrates that learning Infrastructure as Code can produce production-ready systems while maintaining clear documentation and sound architectural decisions.
