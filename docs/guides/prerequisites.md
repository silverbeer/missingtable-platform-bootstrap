# Prerequisites

Complete list of required tools, accounts, and credentials needed to deploy this infrastructure.

## Required Accounts

### AWS Account
- **Required for:** Route 53, Lambda, Secrets Manager, S3, DynamoDB
- **Cost impact:** ~$1/month for Route 53 + minimal Lambda/S3
- **Setup:** [Create AWS account](https://aws.amazon.com/)
- **Permissions needed:** Admin or PowerUser access

**Post-signup steps:**
1. Enable billing alerts
2. Set up MFA on root account
3. Create IAM user with programmatic access
4. Save access key ID and secret access key

### Linode (Akamai) Account
- **Required for:** LKE Kubernetes cluster (production, `clouds/linode/environments/dev`)
- **Cost impact:** one g6-standard-2 node — check current Linode pricing
- **Setup:** [Linode](https://www.linode.com/)

**Post-signup steps:**
1. Add payment method
2. Create a personal access token for the API
3. Save token securely (CI reads it as the `LINODE_TOKEN` GitHub secret)

### GitHub Account
- **Required for:** Container registry (GHCR), CI/CD workflows
- **Cost impact:** Free (public repos + GHCR)
- **Setup:** [Create GitHub account](https://github.com/)

**Post-signup steps:**
1. Generate Personal Access Token:
   - Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Select scopes: `read:packages`, `write:packages`
2. Save token securely

### Domain Name (Optional but Recommended)
- **Required for:** TLS certificates, production URLs
- **Cost impact:** $10-15/year depending on registrar and TLD
- **Options:** Namecheap, GoDaddy, Google Domains, etc.

**Note:** Domain can be registered anywhere. We'll use Route 53 for DNS hosting.

---

## Required Tools

### 1. OpenTofu

**Version:** >= 1.8.0
**Purpose:** Infrastructure as Code (Terraform fork)

#### Installation

**macOS (Homebrew):**
```bash
brew install opentofu
```

**Linux (Snap):**
```bash
snap install --classic opentofu
```

**Manual installation:**
```bash
# Download from https://github.com/opentofu/opentofu/releases
wget https://github.com/opentofu/opentofu/releases/download/v1.8.0/tofu_1.8.0_linux_amd64.zip
unzip tofu_1.8.0_linux_amd64.zip
sudo mv tofu /usr/local/bin/
```

**Verify:**
```bash
tofu version
# Should show: OpenTofu v1.8.0 or later
```

---

### 2. kubectl

**Version:** >= 1.28
**Purpose:** Kubernetes command-line tool

#### Installation

**macOS (Homebrew):**
```bash
brew install kubectl
```

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**Verify:**
```bash
kubectl version --client
# Should show v1.28 or later
```

---

### 3. AWS CLI

**Version:** >= 2.0
**Purpose:** AWS command-line interface

#### Installation

**macOS (Homebrew):**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Configure:**
```bash
aws configure
# Enter your AWS access key ID
# Enter your AWS secret access key
# Default region: us-east-2
# Default output format: json
```

**Verify:**
```bash
aws sts get-caller-identity
# Should show your AWS account ID and ARN
```

---

### 4. Cluster access (kubeconfig)

No cloud-specific CLI is required. The LKE kubeconfig is a sensitive output of
the production stack:

```bash
cd clouds/linode/environments/dev
tofu output -raw kubeconfig > ~/.kube/missingtable-lke.yaml
export KUBECONFIG=~/.kube/missingtable-lke.yaml
kubectl get nodes
```

---

### 5. Docker

**Version:** >= 20.10
**Purpose:** Building Lambda container images

#### Installation

**macOS:**
```bash
brew install --cask docker
# Or download Docker Desktop from docker.com
```

**Linux (Ubuntu/Debian):**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Log out and back in for group changes
```

**Verify:**
```bash
docker --version
# Should show Docker version 20.10 or later

docker run hello-world
# Should successfully pull and run test image
```

---

### 6. GitHub CLI (Optional but Recommended)

**Version:** Latest
**Purpose:** GitHub operations from command line

#### Installation

**macOS (Homebrew):**
```bash
brew install gh
```

**Linux (Debian/Ubuntu):**
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

**Authenticate:**
```bash
gh auth login
# Follow prompts to authenticate with GitHub
```

**Verify:**
```bash
gh auth status
# Should show logged in status
```

---

## Required Credentials & Secrets

Before starting deployment, gather these values:

### AWS Credentials
- [x] **AWS Access Key ID** (format: `AKIA...`)
- [x] **AWS Secret Access Key**
- [x] **AWS Account ID** (12-digit number)

**How to get:**
```bash
aws sts get-caller-identity --query Account --output text
```

### Linode Credentials
- [x] **Linode API token** (exported as `LINODE_TOKEN`)

### GitHub Credentials
- [x] **GitHub Username**
- [x] **GitHub Personal Access Token** with `read:packages` scope

**How to get:** Settings → Developer settings → Personal access tokens

### Application Secrets (if deploying example apps)
- [x] **Database URL** (PostgreSQL connection string)
- [x] **Supabase URL**
- [x] **Supabase Anon Key**
- [x] **Supabase JWT Secret**

### Email
- [x] **Email address** for Let's Encrypt certificate notifications

---

## Recommended but Optional

### Text Editor with HCL Support
- **VS Code** with HashiCorp Terraform extension
- **IntelliJ IDEA** with Terraform plugin
- **Vim** with terraform.vim

### Version Control
- **Git** (should be pre-installed on macOS/Linux)

### Terminal Multiplexer
- **tmux** or **screen** for managing multiple terminals

### DNS Tools
- **dig** for DNS troubleshooting (usually pre-installed)
- **nslookup** alternative to dig

---

## Verification Checklist

Before proceeding with deployment, verify all tools are installed:

```bash
# Check all required tools
echo "=== Tool Versions ==="
tofu version
kubectl version --client --short
aws --version
docker --version
gh --version 2>/dev/null || echo "gh CLI not installed (optional)"

# Check AWS authentication
echo -e "\n=== AWS Account ==="
aws sts get-caller-identity

# Check Docker
echo -e "\n=== Docker ==="
docker info | grep "Server Version"

echo -e "\n✅ All prerequisites verified!"
```

Run this script to verify everything is set up correctly.

---

## Estimated Costs

### One-time Costs
- Domain registration: $10-15/year

### Monthly Recurring Costs
- **LKE cluster:** one g6-standard-2 node (production — do not destroy)
- **Route 53:** $1/month (2 hosted zones at $0.50 each)
- **Lambda executions:** ~$0 (free tier covers daily certificate checks)
- **S3 state storage:** ~$0 (minimal usage)
- **Secrets Manager:** ~$0.40/month (2 secrets at $0.40/secret/month)

**Total:** LKE node + ~$1/month

### Cost Optimization Tips
- Lambda and S3 stay within free tier for this workload
- Route 53 cost is fixed but minimal

---

## Next Steps

Once all prerequisites are met:
1. [Getting Started Guide](getting-started.md) - Step-by-step deployment
2. [Architecture Overview](../architecture/overview.md) - Understand the system design
3. [GitHub Branch Protection](github-branch-protection.md) - Set up workflow rules

---

## Troubleshooting

### AWS CLI not working
```bash
# Check configuration
aws configure list

# Reconfigure if needed
aws configure
```

### kubectl not found
```bash
# Check if in PATH
echo $PATH

# Find kubectl location
which kubectl
```

### Docker permission denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run
newgrp docker
```

---

**Ready to proceed?** Head to the [Getting Started Guide](getting-started.md)!
