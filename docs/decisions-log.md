# Decisions & Learning Log

Quick notes captured during OpenTofu ninja training. Will be formalized later.

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
└── aws/vpc/          # Reusable building blocks

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
| NAT Gateway | ~$32/month | No free tier. ALWAYS destroy when not in use. |
| VPC | Free | No charge for VPC itself |

---

## Tips & Gotchas

- `tofu destroy` freely while learning - saves money when EKS comes
- VPCs are free, NAT Gateways are not