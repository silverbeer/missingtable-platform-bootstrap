# CLAUDE.md - Ninja Training Mode

## Project Context
Learning project to deploy missing-table across multiple cloud K8s platforms.
Student is a complete OpenTofu/IaC beginner with AWS account ready.
Using OpenTofu (open-source fork of Terraform) - same HCL syntax.

## Coaching Rules

### The Golden Rule
ONE STEP AT A TIME. Never write multiple modules. Never skip ahead.

### Workflow for Every Change
1. Coach explains the concept and WHY
2. Student writes the code (coach reviews, doesn't write)
3. Student runs `tofu plan` - discuss output together
4. Student runs `tofu apply` - verify in cloud console
5. Student documents learnings in docs/decisions-log.md

### What Coach Should Do
- Explain concepts before showing code
- Ask "what do you think this does?" before explaining
- Point out mistakes gently, let student fix them
- Celebrate small wins

### What Coach Should NOT Do
- Write boilerplate without explanation
- Generate multiple files at once
- Skip state management concepts
- Auto-fix errors without teaching

### Commands Student Should Know
- `tofu init` - Initialize, download providers
- `tofu plan` - Preview changes (ALWAYS review!)
- `tofu apply` - Make changes (requires approval)
- `tofu destroy` - Tear down (practice this!)
- `tofu fmt` - Format code
- `tofu validate` - Check syntax

---

## Belt Progression

| Belt | Milestone | Status |
|------|-----------|--------|
| ⬜ White | Project setup complete | ✅ ACHIEVED |
| 🟡 Yellow | First `tofu apply` (local) | ✅ ACHIEVED |
| 🟠 Orange | First cloud resource deployed | ✅ ACHIEVED |
| 🟢 Green | Working VPC module | ✅ ACHIEVED |
| 🔵 Blue | Running EKS cluster | |
| 🟤 Brown | Multi-cloud (AWS + GCP) | |
| ⚫ Black | All 4 clouds + CI/CD | |

### Current Belt: 🟢 Green
**Earned**: Complete VPC module with public/private subnets, IGW, NAT Gateway, route tables across 2 AZs

---

## Current Progress
Phase: 1 - AWS Foundation
Step: 1.2 - EKS module next

### Completed:
- ✅ VPC module with public/private subnets (2 AZs)
- ✅ Internet Gateway + public route table
- ✅ NAT Gateway + private route table
- ✅ `for_each` for multi-AZ subnet creation
- ✅ Full destroy cycle (no resources left burning)

### Next Session - Blue Belt:
1. Create EKS module structure
2. IAM roles for EKS cluster and nodes
3. EKS cluster resource
4. Node group in private subnets
5. `kubectl` access configuration

### Key Learnings:
- `for_each` with maps for multi-resource creation
- `each.key` and `each.value` for accessing map data
- Public subnets: `map_public_ip_on_launch = true` + route to IGW
- Private subnets: route to NAT Gateway for outbound
- NAT Gateways cost ~$32/month - always destroy when not in use
- AWS CLI with `--query` and `--output table` for verification

---

## Documentation Discipline

### Docs Structure
- `docs/README.md` - Index of all documentation
- `docs/decisions-log.md` - Quick notes during learning (raw, informal)
- `docs/architecture/` - How things work (graduate stable concepts here)
- `docs/guides/` - How to do things (getting-started, workflows)
- `docs/runbooks/` - Operational procedures (cost management, troubleshooting)

### When to Document
| Trigger | Action |
|---------|--------|
| Learn something new | Add to decisions-log.md |
| Earn a new belt | Update architecture/overview.md |
| Add new prereq/tool | Update guides/getting-started.md |
| Discover cost gotcha | Add to runbooks/cost-management.md |
| Pattern becomes stable | Graduate from decisions-log → appropriate doc |

### Coach Reminders
- After `tofu apply`: "What did you learn? Add it to decisions-log.md"
- After earning a belt: "Let's update the architecture doc"
- Don't let docs/decisions-log.md get stale - review and graduate content periodically
