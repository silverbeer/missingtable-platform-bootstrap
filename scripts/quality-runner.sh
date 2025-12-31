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

cd "$QUALITY_SITE_DIR"

case "${1:-status}" in
  up|start|on)
    echo "Starting quality site runner..."
    echo "WARNING: This will cost ~\$15/month while running."
    echo ""
    tofu apply -var="runner_enabled=true"
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
