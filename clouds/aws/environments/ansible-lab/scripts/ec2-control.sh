#!/bin/bash
# EC2 Start/Stop script for ansible-lab
# Usage: ./ec2-control.sh [start|stop|status]

set -e

INSTANCE_ID=$(tofu -chdir="$(dirname "$0")/.." output -raw instance_id 2>/dev/null || echo "")
REGION="us-east-2"
INVENTORY_FILE="$(dirname "$0")/../ansible/inventory/hosts.yml"

if [ -z "$INSTANCE_ID" ]; then
    echo "Error: Could not get instance ID. Is infrastructure deployed?"
    echo "Run: tofu apply"
    exit 1
fi

case "${1:-status}" in
    start)
        echo "Starting instance $INSTANCE_ID..."
        aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
        echo "Waiting for instance to be running..."
        aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

        # Get new public IP
        NEW_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

        echo "Instance running. New IP: $NEW_IP"
        echo ""
        echo "Updating inventory file..."
        sed -i.bak "s/ansible_host: .*/ansible_host: $NEW_IP/" "$INVENTORY_FILE"
        rm -f "${INVENTORY_FILE}.bak"
        echo "Updated $INVENTORY_FILE"
        echo ""
        echo "SSH command: ssh -i ~/.ssh/ansible-lab ubuntu@$NEW_IP"
        ;;
    stop)
        echo "Stopping instance $INSTANCE_ID..."
        aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
        echo "Instance stopping. EBS storage cost: ~$0.16/month"
        ;;
    status)
        STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
            --query 'Reservations[0].Instances[0].State.Name' --output text)
        IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

        echo "Instance: $INSTANCE_ID"
        echo "State:    $STATE"
        [ "$IP" != "None" ] && echo "IP:       $IP"
        ;;
    *)
        echo "Usage: $0 [start|stop|status]"
        exit 1
        ;;
esac
