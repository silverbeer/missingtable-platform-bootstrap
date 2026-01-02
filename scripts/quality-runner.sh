#!/usr/bin/env bash
#
# quality-runner.sh - Manage the quality site GitHub Actions runner
#
# Usage:
#   ./scripts/quality-runner.sh up      # Start runner (~$15/mo)
#   ./scripts/quality-runner.sh down    # Stop runner (saves money)
#   ./scripts/quality-runner.sh status  # Check current state
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUALITY_SITE_DIR="$SCRIPT_DIR/../clouds/aws/global/quality-site"
ANSIBLE_INVENTORY="$QUALITY_SITE_DIR/ansible/inventory/quality-runner.yml"

cd "$QUALITY_SITE_DIR"

update_ansible_inventory() {
  local public_ip="$1"
  echo "Updating Ansible inventory with IP: $public_ip"
  cat > "$ANSIBLE_INVENTORY" << EOF
all:
  hosts:
    quality-runner:
      ansible_host: $public_ip
      ansible_python_interpreter: /usr/bin/python3
EOF
}

refresh_runner_token() {
  echo "Generating new GitHub runner registration token..."
  local token
  token=$(gh api repos/silverbeer/missing-table/actions/runners/registration-token --method POST --jq '.token')
  aws secretsmanager put-secret-value \
    --secret-id quality-site/github-runner-token \
    --secret-string "$token" \
    --region us-east-2 > /dev/null
  echo "Token updated in Secrets Manager"
}

case "${1:-status}" in
  up|start|on)
    echo "Starting quality site runner..."
    echo "WARNING: This will cost ~\$15/month while running."
    echo ""
    tofu apply -var="runner_enabled=true"

    # Get the public IP and update Ansible inventory
    PUBLIC_IP=$(tofu output -raw runner_public_ip 2>/dev/null || echo "")
    if [ -n "$PUBLIC_IP" ]; then
      update_ansible_inventory "$PUBLIC_IP"
      refresh_runner_token

      echo ""
      echo "To configure the runner, run:"
      echo "  cd $QUALITY_SITE_DIR/ansible && ansible-playbook playbooks/configure-runner.yml"
    fi

    echo ""
    echo "Runner is UP. Don't forget to run './scripts/quality-runner.sh down' when done!"
    ;;
    
  down|stop|off)
    echo "Stopping quality site runner..."
    tofu apply -var="runner_enabled=false" -auto-approve
    echo ""
    echo "Runner is DOWN. Cost savings: ~\$15/month"
    ;;
    
  status)
    echo "Quality Site Runner Status"
    echo "=========================="
    if tofu state list 2>/dev/null | grep -q "aws_instance.runner\[0\]"; then
      echo "Status: UP (costing ~\$15/mo)"
      echo ""
      tofu state show 'aws_instance.runner[0]' 2>/dev/null | grep -E "public_ip|instance_state" | head -2 || true
    else
      echo "Status: DOWN (no cost)"
    fi
    ;;
    
  *)
    echo "Usage: $0 {up|down|status}"
    echo ""
    echo "Commands:"
    echo "  up      Start the runner (~\$15/mo)"
    echo "  down    Stop the runner (saves money)"
    echo "  status  Check if runner is on or off"
    exit 1
    ;;
esac
