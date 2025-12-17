#!/bin/bash
# List all AWS resources for a given environment using resource tagging API
# Usage: ./list-aws-resources.sh [environment] [--global] [--costs]
#
# Examples:
#   ./list-aws-resources.sh dev              # List dev resources in us-east-2
#   ./list-aws-resources.sh dev --global     # Include global resources (IAM, etc.)
#   ./list-aws-resources.sh dev --costs      # Show cost estimates
#   ./list-aws-resources.sh prod us-west-2   # Different region

set -euo pipefail

# Defaults
ENV="dev"
REGION="us-east-2"
PROJECT="missing-table"
SHOW_GLOBAL=false
SHOW_COSTS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --global|-g)
            SHOW_GLOBAL=true
            shift
            ;;
        --costs|-c)
            SHOW_COSTS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [environment] [region] [--global] [--costs]"
            echo ""
            echo "Options:"
            echo "  environment    Environment tag to filter (default: dev)"
            echo "  region         AWS region (default: us-east-2)"
            echo "  --global, -g   Include global resources (IAM, Route53, etc.)"
            echo "  --costs, -c    Show cost estimates for the last 7 days"
            echo "  --help, -h     Show this help"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            if [[ "$1" =~ ^[a-z]+-[a-z]+-[0-9]+$ ]]; then
                REGION="$1"
            else
                ENV="$1"
            fi
            shift
            ;;
    esac
done

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    GRAY='\033[0;90m'
    NC='\033[0m'
    BOLD='\033[1m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' GRAY='' NC='' BOLD=''
fi

print_header() {
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  AWS Resources: ${PROJECT} / ${ENV} / ${REGION}${NC}"
    if $SHOW_GLOBAL; then
        echo -e "${BOLD}${BLUE}  (including global resources)${NC}"
    fi
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

get_service_icon() {
    case "$1" in
        ec2)                  echo "🖥️ " ;;
        eks)                  echo "☸️ " ;;
        elasticloadbalancing) echo "⚖️ " ;;
        s3)                   echo "🪣" ;;
        rds)                  echo "🗄️ " ;;
        lambda)               echo "λ  " ;;
        iam)                  echo "🔐" ;;
        kms)                  echo "🔑" ;;
        secretsmanager)       echo "🔒" ;;
        logs)                 echo "📋" ;;
        autoscaling)          echo "📈" ;;
        route53)              echo "🌐" ;;
        acm)                  echo "📜" ;;
        dynamodb)             echo "⚡" ;;
        *)                    echo "📦" ;;
    esac
}

get_friendly_service_name() {
    case "$1" in
        ec2)                  echo "EC2 (Compute)" ;;
        eks)                  echo "EKS (Kubernetes)" ;;
        elasticloadbalancing) echo "Load Balancers" ;;
        s3)                   echo "S3 (Storage)" ;;
        rds)                  echo "RDS (Database)" ;;
        lambda)               echo "Lambda (Functions)" ;;
        iam)                  echo "IAM (Identity)" ;;
        kms)                  echo "KMS (Encryption)" ;;
        secretsmanager)       echo "Secrets Manager" ;;
        logs)                 echo "CloudWatch Logs" ;;
        autoscaling)          echo "Auto Scaling" ;;
        route53)              echo "Route 53 (DNS)" ;;
        acm)                  echo "ACM (Certificates)" ;;
        dynamodb)             echo "DynamoDB" ;;
        *)                    echo "$1" ;;
    esac
}

# Estimated monthly costs by resource type (rough estimates)
get_estimated_cost() {
    local service="$1"
    local resource_type="$2"

    case "$service:$resource_type" in
        eks:cluster)          echo "72.00" ;;   # EKS control plane
        eks:nodegroup)        echo "0.00" ;;    # Depends on instances
        ec2:instance)         echo "varies" ;;
        ec2:natgateway)       echo "32.00" ;;   # ~$0.045/hr + data
        ec2:vpc)              echo "0.00" ;;
        ec2:subnet)           echo "0.00" ;;
        ec2:internet-gateway) echo "0.00" ;;
        ec2:route-table)      echo "0.00" ;;
        ec2:elastic-ip)       echo "3.60" ;;    # If unattached
        elasticloadbalancing:*) echo "16.00" ;; # ALB minimum
        rds:*)                echo "varies" ;;
        lambda:*)             echo "0.00" ;;    # Free tier usually covers it
        s3:*)                 echo "varies" ;;
        secretsmanager:*)     echo "0.40" ;;    # Per secret/month
        route53:hostedzone)   echo "0.50" ;;
        dynamodb:table)       echo "0.00" ;;    # On-demand, pay per use
        *)                    echo "" ;;
    esac
}

print_header

echo -e "${CYAN}Querying tagged resources...${NC}"
echo ""

# Build regions to query
REGIONS=("$REGION")
if $SHOW_GLOBAL; then
    REGIONS+=("us-east-1")  # Global services are often in us-east-1
fi

# Collect all resources
ALL_RESOURCES=""

for r in "${REGIONS[@]}"; do
    RESOURCES_JSON=$(aws resourcegroupstaggingapi get-resources \
        --region "$r" \
        --tag-filters \
            "Key=project,Values=${PROJECT}" \
            "Key=environment,Values=${ENV}" \
        --output json 2>/dev/null || echo '{"ResourceTagMappingList":[]}')

    # Extract ARN and name tag
    PARSED=$(echo "$RESOURCES_JSON" | jq -r '
        .ResourceTagMappingList[] |
        .ResourceARN as $arn |
        (.Tags // [] | map(select(.Key == "name" or .Key == "Name")) | .[0].Value // "") as $name |
        "\($arn)\t\($name)"
    ')

    if [ -n "$PARSED" ]; then
        ALL_RESOURCES+="$PARSED"$'\n'
    fi
done

# Also check global environment if --global
if $SHOW_GLOBAL; then
    GLOBAL_JSON=$(aws resourcegroupstaggingapi get-resources \
        --region "us-east-1" \
        --tag-filters \
            "Key=project,Values=${PROJECT}" \
            "Key=environment,Values=global" \
        --output json 2>/dev/null || echo '{"ResourceTagMappingList":[]}')

    PARSED=$(echo "$GLOBAL_JSON" | jq -r '
        .ResourceTagMappingList[] |
        .ResourceARN as $arn |
        (.Tags // [] | map(select(.Key == "name" or .Key == "Name")) | .[0].Value // "") as $name |
        "\($arn)\t\($name)"
    ')

    if [ -n "$PARSED" ]; then
        ALL_RESOURCES+="$PARSED"$'\n'
    fi
fi

# Remove empty lines and count
ALL_RESOURCES=$(echo "$ALL_RESOURCES" | grep -v '^$' || true)
RESOURCE_COUNT=$(echo "$ALL_RESOURCES" | grep -c . || echo 0)

if [ "$RESOURCE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No resources found with tags:${NC}"
    echo -e "  project=${PROJECT}"
    echo -e "  environment=${ENV}"
    echo ""
    echo -e "${CYAN}Tips:${NC}"
    echo -e "  - EKS cluster may not be running (saves \$72/month)"
    echo -e "  - Run 'tofu apply' to create resources"
    echo -e "  - Check tags in AWS console"
    exit 0
fi

# Process and display resources grouped by service
# First sort by service then by name, then process
echo "$ALL_RESOURCES" | sort -t$'\t' -k1,1 | awk -F'\t' '
BEGIN {
    current_service = ""
    total = 0
}
{
    arn = $1
    name_tag = $2

    # Parse ARN: arn:aws:service:region:account:resource-type/resource-id
    split(arn, parts, ":")
    service = parts[3]

    # Get resource type and id from the last part
    resource_part = parts[6]
    for (i = 7; i <= length(parts); i++) {
        resource_part = resource_part ":" parts[i]
    }

    # Split resource_part by / to get type and id
    n = split(resource_part, res, "/")
    if (n >= 2) {
        resource_type = res[1]
        resource_id = res[n]
    } else {
        resource_type = ""
        resource_id = resource_part
    }

    # Use name tag if available, otherwise use resource_id
    display_name = (name_tag != "") ? name_tag : resource_id

    # Group by service
    if (service != current_service) {
        if (current_service != "") {
            print ""
        }
        current_service = service

        # Print service header with friendly name
        printf "\033[1m\033[0;32m"
        if (service == "ec2") printf "🖥️  EC2 (Compute)"
        else if (service == "eks") printf "☸️  EKS (Kubernetes)"
        else if (service == "elasticloadbalancing") printf "⚖️  Load Balancers"
        else if (service == "s3") printf "🪣 S3 (Storage)"
        else if (service == "lambda") printf "λ  Lambda (Functions)"
        else if (service == "iam") printf "🔐 IAM (Identity)"
        else if (service == "secretsmanager") printf "🔒 Secrets Manager"
        else if (service == "route53") printf "🌐 Route 53 (DNS)"
        else if (service == "acm") printf "📜 ACM (Certificates)"
        else if (service == "dynamodb") printf "⚡ DynamoDB"
        else if (service == "logs") printf "📋 CloudWatch Logs"
        else if (service == "autoscaling") printf "📈 Auto Scaling"
        else printf "📦 " toupper(service)
        printf "\033[0m\n"
    }

    # Print resource with type indicator
    type_label = ""
    cost_hint = ""

    if (resource_type == "vpc") { type_label = "vpc"; cost_hint = "" }
    else if (resource_type == "subnet") { type_label = "subnet"; cost_hint = "" }
    else if (resource_type == "internet-gateway") { type_label = "igw"; cost_hint = "" }
    else if (resource_type == "natgateway") { type_label = "nat"; cost_hint = "~$32/mo" }
    else if (resource_type == "route-table") { type_label = "rtb"; cost_hint = "" }
    else if (resource_type == "elastic-ip") { type_label = "eip"; cost_hint = "" }
    else if (resource_type == "cluster") { type_label = "cluster"; cost_hint = "~$72/mo" }
    else if (resource_type == "nodegroup") { type_label = "nodegroup"; cost_hint = "" }
    else if (resource_type == "secret") { type_label = "secret"; cost_hint = "~$0.40/mo" }
    else if (resource_type == "hostedzone") { type_label = "zone"; cost_hint = "~$0.50/mo" }
    else if (resource_type == "certificate") { type_label = "cert"; cost_hint = "" }
    else if (resource_type == "function") { type_label = "func"; cost_hint = "" }
    else if (resource_type == "table") { type_label = "table"; cost_hint = "" }
    else { type_label = resource_type }

    # Format output
    if (type_label != "") {
        printf "   └─ \033[0;90m[%s]\033[0m %s", type_label, display_name
    } else {
        printf "   └─ %s", display_name
    }

    if (cost_hint != "") {
        printf " \033[0;33m%s\033[0m", cost_hint
    }
    printf "\n"

    total++
}
END {
    print ""
    printf "\033[1m\033[0;34m══════════════════════════════════════════════════════════════════════════\033[0m\n"
    printf "\033[1mTotal: %d resources\033[0m\n", total
    printf "\033[1m\033[0;34m══════════════════════════════════════════════════════════════════════════\033[0m\n"
}'

echo ""

# Show actual costs if requested
if $SHOW_COSTS; then
    echo -e "${BOLD}${CYAN}Cost Analysis (Last 7 Days)${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────${NC}"

    # Calculate date range (macOS compatible)
    if date -v-7d &>/dev/null; then
        # macOS
        START_DATE=$(date -v-7d +%Y-%m-%d)
        END_DATE=$(date +%Y-%m-%d)
    else
        # Linux
        START_DATE=$(date -d '7 days ago' +%Y-%m-%d)
        END_DATE=$(date +%Y-%m-%d)
    fi

    # Get costs grouped by service
    COSTS=$(aws ce get-cost-and-usage \
        --time-period "Start=${START_DATE},End=${END_DATE}" \
        --granularity MONTHLY \
        --metrics "UnblendedCost" \
        --group-by Type=DIMENSION,Key=SERVICE \
        --filter "{\"Tags\":{\"Key\":\"project\",\"Values\":[\"${PROJECT}\"]}}" \
        --output json 2>/dev/null || echo '{"ResultsByTime":[]}')

    if [ "$(echo "$COSTS" | jq '.ResultsByTime | length')" -gt 0 ]; then
        echo "$COSTS" | jq -r '
            .ResultsByTime[0].Groups[] |
            select(.Metrics.UnblendedCost.Amount | tonumber > 0.01) |
            "\(.Keys[0])\t$\(.Metrics.UnblendedCost.Amount | tonumber | . * 100 | floor / 100)"
        ' | sort -t$'\t' -k2 -rn | while IFS=$'\t' read -r service cost; do
            printf "   %-40s %s\n" "$service" "$cost"
        done

        # Total
        TOTAL=$(echo "$COSTS" | jq -r '[.ResultsByTime[0].Groups[].Metrics.UnblendedCost.Amount | tonumber] | add | . * 100 | floor / 100')
        echo ""
        echo -e "   ${BOLD}Total (7 days):                          \$${TOTAL}${NC}"

        # Estimate monthly
        MONTHLY=$(echo "$TOTAL" | awk '{printf "%.2f", $1 / 7 * 30}')
        echo -e "   ${GRAY}Estimated monthly:                       ~\$${MONTHLY}${NC}"
    else
        echo -e "   ${YELLOW}No cost data available (costs may take 24-48h to appear)${NC}"
    fi

    echo ""
fi

# Show helpful commands
echo -e "${CYAN}Useful commands:${NC}"
echo -e "  ${GRAY}# Destroy EKS to save ~\$72/month:${NC}"
echo -e "  cd clouds/aws/environments/${ENV} && tofu destroy -target=module.eks"
echo ""
