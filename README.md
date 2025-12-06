  # missingtable-platform-bootstrap

  Multi-cloud Kubernetes infrastructure for deploying missing-table.

  ## Goal

  Learn OpenTofu and Kubernetes by deploying the same application across:
  - [ ] AWS EKS
  - [ ] GCP GKE Autopilot
  - [ ] Azure AKS
  - [ ] DigitalOcean DOKS

  ## Current Status

  **Phase 0**: Foundation Setup

  ## Structure

  clouds/         # Cloud-specific entry points
  modules/        # Reusable OpenTofu modules
  global/         # Cross-cloud tooling
  learn/          # OpenTofu practice exercises
  docs/           # Architecture decisions
  scripts/        # Helper scripts

  ## Tools

  - **IaC**: OpenTofu (open-source Terraform fork)
  - **Container Orchestration**: Kubernetes