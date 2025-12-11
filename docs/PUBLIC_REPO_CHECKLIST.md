# Public Repository Preparation - Hands-On Checklist

**Goal**: Make this repository public-ready with working CI/CD pipeline

**Timeline**: 15-16 hours (spread over 3-5 days)
**Learning Mode**: You write the code, Claude coaches

---

## Phase 1: Critical Security & Functionality Fixes (2 hours)

### ✅ Task 1.1: Fix Lambda Syntax Error
**File**: `clouds/aws/global/certificate-management/lambda/handler.py`

**Problem**: Syntax error on line 1 preventing Lambda execution

**What You'll Learn**:
- Python indentation rules
- Lambda function structure

**Steps**:
1. Open `handler.py` in your editor
2. Find the syntax error (look at line 1 indentation)
3. Fix the indentation
4. Verify: `python3 handler.py` should parse without errors

**Success Criteria**: File parses without syntax errors

---

### 🎯 Task 1.2: Add ACM Certificate Upload
**File**: `clouds/aws/global/certificate-management/lambda/handler.py`

**Goal**: Upload certificates to both Secrets Manager AND AWS Certificate Manager

**What You'll Learn**:
- AWS ACM API (ImportCertificate)
- Multi-destination certificate management
- Why: DOKS uses Secrets Manager → External Secrets, EKS will use ACM directly

**Current Code** (lines 56-67):
```python
# Store in Secrets Manager (format for K8s TLS secret)
secrets_client = boto3.client("secretsmanager")
secret_value = json.dumps({
    "fullchain": cert,
    "private_key": key,
    "certificate": cert
})

secrets_client.put_secret_value(
    SecretId=secret_id,
    SecretString=secret_value
)
```

**Add After Line 67**:
```python
# Also import to ACM for EKS Load Balancers
acm_client = boto3.client('acm', region_name='us-east-2')

# Read the certificate chain
with open(os.path.join(cert_path, "chain.pem")) as f:
    chain = f.read()

# Import certificate to ACM
response = acm_client.import_certificate(
    Certificate=cert.encode(),
    PrivateKey=key.encode(),
    CertificateChain=chain.encode()
)

certificate_arn = response['CertificateArn']
print(f"Certificate imported to ACM: {certificate_arn}")
```

**Update Return Statement** (line 69-72):
```python
return {
    "statusCode": 200,
    "body": json.dumps({
        "message": f"Certificate for {domain} renewed and stored",
        "secrets_manager": secret_id,
        "acm_arn": certificate_arn
    })
}
```

**Success Criteria**: Lambda code includes ACM import logic

---

### 🔒 Task 1.3: Remove Personal Email
**File**: `clouds/aws/global/certificate-management/variables.tf`

**Problem**: Line 10 has your personal email as default value

**What You'll Learn**:
- Sensitive data management
- Variable best practices

**Steps**:
1. Open `variables.tf`
2. Find the `letsencrypt_email` variable (around line 10)
3. Remove the `default` line entirely
4. This forces users to provide their own email

**Before**:
```hcl
variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt notifications"
  type        = string
  default     = "silverbeer.io@gmail.com"  # ❌ Your personal email!
}
```

**After**:
```hcl
variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt notifications"
  type        = string
  # No default - user must provide their own email
}
```

**Success Criteria**: No personal email in code

---

### 🏷️ Task 1.4: Parameterize GitHub Username
**Files**:
- `clouds/digitalocean/environments/dev/main.tf`
- Any docs with hardcoded "silverbeer"

**Problem**: Your username "silverbeer" is hardcoded in GHCR image references

**What You'll Learn**:
- Making code reusable
- Variable interpolation in Terraform

**Find and Replace**:
```hcl
# Before
image = "ghcr.io/silverbeer/missing-table-backend:latest"

# After
image = "ghcr.io/${var.ghcr_username}/missing-table-backend:latest"
```

**Note**: The variable `ghcr_username` already exists! Just use it consistently.

**Steps**:
1. Search for "silverbeer" in `main.tf`: `grep -n "silverbeer" clouds/digitalocean/environments/dev/main.tf`
2. Replace each hardcoded username with `${var.ghcr_username}`
3. Verify: `grep "silverbeer" clouds/digitalocean/environments/dev/main.tf` returns nothing

**Success Criteria**: No hardcoded username in infrastructure code

---

### 📄 Task 1.5: Add MIT LICENSE
**File**: `/LICENSE` (new file)

**What You'll Learn**:
- Open source licensing
- Why LICENSE files matter

**Steps**:
1. Create new file `LICENSE` in repository root
2. Copy MIT License text (see below)
3. Update year and copyright holder

**MIT License Template**:
```
MIT License

Copyright (c) 2025 [Your Name or silverbeer]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Success Criteria**: LICENSE file exists in repository root

---

### 🔐 Task 1.6: Add ACM Permissions to Lambda IAM Role
**File**: `clouds/aws/global/certificate-management/main.tf`

**Goal**: Allow Lambda to import certificates to ACM

**What You'll Learn**:
- AWS IAM policies
- Lambda permissions
- Least-privilege security

**Add After** the existing `aws_iam_role_policy` resources (around line 114):

```hcl
resource "aws_iam_role_policy" "lambda_acm" {
  name = "acm-import"
  role = aws_iam_role.certbot_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm:ImportCertificate",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "acm:AddTagsToCertificate"
        ]
        Resource = "*"
      }
    ]
  })
}
```

**Success Criteria**: Lambda IAM role has ACM permissions

---

### 🧪 Task 1.7: Test and Commit Phase 1
**Commands**:
```bash
# Validate Terraform syntax
cd clouds/aws/global/certificate-management
tofu validate

cd ../../../digitalocean/environments/dev
tofu validate

# Format code
tofu fmt -recursive

# Stage changes
git add .
git status  # Review what you're committing

# Commit with descriptive message
git commit -m "Phase 1: Security fixes and ACM integration

- Fix Lambda handler.py syntax error
- Add ACM certificate import to Lambda
- Remove personal email from variables
- Parameterize GitHub username
- Add MIT LICENSE
- Add ACM permissions to Lambda IAM role

Prepares repository for public release and enables
dual-destination certificate management (Secrets Manager
for DOKS, ACM for future EKS deployments)."
```

**Success Criteria**: Phase 1 changes committed to branch

---

## Phase 2: Remote State Backend Configuration (1 hour)

### 📦 Task 2.1: Create S3 Bucket for Terraform State
**File**: `clouds/aws/global/terraform-state/main.tf` (new file)

**What You'll Learn**:
- S3 backend for Terraform state
- State locking with DynamoDB
- Why remote state matters for CI/CD

**Create Directory**:
```bash
mkdir -p clouds/aws/global/terraform-state
```

**Create `main.tf`**:
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "missingtable-terraform-state"

  tags = {
    Name        = "Terraform State"
    Environment = "global"
    ManagedBy   = "terraform"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_lock" {
  name           = "terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock"
    Environment = "global"
    ManagedBy   = "terraform"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_lock.name
}
```

**Deploy**:
```bash
cd clouds/aws/global/terraform-state
tofu init
tofu plan
tofu apply
```

**Success Criteria**: S3 bucket and DynamoDB table created in AWS

---

### 🔄 Task 2.2: Configure Backend in Certificate Management
**File**: `clouds/aws/global/certificate-management/main.tf`

**Add to top of file** (after the `terraform` block):

```hcl
terraform {
  backend "s3" {
    bucket         = "missingtable-terraform-state"
    key            = "aws/global/certificate-management/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }

  # ... rest of existing terraform block
}
```

**Migrate State**:
```bash
cd clouds/aws/global/certificate-management
tofu init -migrate-state
# Type "yes" when prompted
```

**Success Criteria**: State migrated to S3

---

### 🔄 Task 2.3: Configure Backend in DOKS Environment
**File**: `clouds/digitalocean/environments/dev/main.tf`

**Add backend configuration** (same pattern as above):

```hcl
terraform {
  backend "s3" {
    bucket         = "missingtable-terraform-state"
    key            = "digitalocean/environments/dev/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }

  # ... rest of existing terraform block
}
```

**Migrate State**:
```bash
cd clouds/digitalocean/environments/dev
tofu init -migrate-state
```

**Success Criteria**: Both environments using S3 backend

---

## Phase 3: Fix GitHub Actions Workflow (1.5 hours)

### 🤖 Task 3.1: Add GitHub Secrets

**What You'll Learn**:
- GitHub Actions secrets
- Environment variables in CI/CD
- Why workflows were hanging

**Add All Secrets**:
```bash
# Use actual values from your terraform.tfvars
gh secret set TF_VAR_database_url --body "YOUR_VALUE"
gh secret set TF_VAR_supabase_url --body "YOUR_VALUE"
gh secret set TF_VAR_supabase_anon_key --body "YOUR_VALUE"
gh secret set TF_VAR_supabase_jwt_secret --body "YOUR_VALUE"
gh secret set TF_VAR_letsencrypt_email --body "YOUR_VALUE"
gh secret set TF_VAR_ghcr_username --body "YOUR_VALUE"
gh secret set TF_VAR_ghcr_token --body "YOUR_VALUE"
gh secret set TF_VAR_aws_access_key_id --body "YOUR_VALUE"
gh secret set TF_VAR_aws_secret_access_key --body "YOUR_VALUE"
```

**Verify**:
```bash
gh secret list
```

**Success Criteria**: All 9 secrets added to GitHub repository

---

### ⚙️ Task 3.2: Update Workflow File
**File**: `.github/workflows/k8s-infra-pipeline.yml`

**What You'll Learn**:
- GitHub Actions workflow syntax
- Environment variable passing
- Auto-approve for non-interactive commands

**Replace the workflow file** with:

```yaml
name: K8s Infra Pipeline

on:
  workflow_dispatch:
    inputs:
      command:
        description: 'OpenTofu command to run'
        required: true
        default: 'plan'
        type: choice
        options:
          - plan
          - apply
          - destroy
      cloud:
        description: 'Cloud provider'
        required: true
        default: 'digitalocean'
        type: choice
        options:
          - digitalocean
      environment:
        description: 'Environment'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup OpenTofu
        uses: opentofu/setup-opentofu@v1
        with:
          tofu_version: 1.6.0

      - name: Configure cloud credentials and variables
        run: |
          echo "DIGITALOCEAN_TOKEN=${{ secrets.DIGITALOCEAN_TOKEN }}" >> $GITHUB_ENV
          echo "TF_VAR_database_url=${{ secrets.TF_VAR_database_url }}" >> $GITHUB_ENV
          echo "TF_VAR_supabase_url=${{ secrets.TF_VAR_supabase_url }}" >> $GITHUB_ENV
          echo "TF_VAR_supabase_anon_key=${{ secrets.TF_VAR_supabase_anon_key }}" >> $GITHUB_ENV
          echo "TF_VAR_supabase_jwt_secret=${{ secrets.TF_VAR_supabase_jwt_secret }}" >> $GITHUB_ENV
          echo "TF_VAR_letsencrypt_email=${{ secrets.TF_VAR_letsencrypt_email }}" >> $GITHUB_ENV
          echo "TF_VAR_ghcr_username=${{ secrets.TF_VAR_ghcr_username }}" >> $GITHUB_ENV
          echo "TF_VAR_ghcr_token=${{ secrets.TF_VAR_ghcr_token }}" >> $GITHUB_ENV
          echo "TF_VAR_aws_access_key_id=${{ secrets.TF_VAR_aws_access_key_id }}" >> $GITHUB_ENV
          echo "TF_VAR_aws_secret_access_key=${{ secrets.TF_VAR_aws_secret_access_key }}" >> $GITHUB_ENV

      - name: Initialize OpenTofu
        working-directory: clouds/${{ inputs.cloud }}/environments/${{ inputs.environment }}
        run: tofu init

      - name: Run OpenTofu command
        working-directory: clouds/${{ inputs.cloud }}/environments/${{ inputs.environment }}
        run: |
          if [ "${{ inputs.command }}" = "plan" ]; then
            tofu plan
          else
            tofu ${{ inputs.command }} -auto-approve
          fi
```

**Success Criteria**: Workflow file updated with all variables and auto-approve

---

### 🧪 Task 3.3: Test Workflow
**Steps**:
1. Commit and push changes
2. Go to GitHub Actions tab
3. Run "K8s Infra Pipeline" workflow manually
4. Select: `command=plan`, `cloud=digitalocean`, `environment=dev`
5. Watch it run successfully!

**Success Criteria**: Workflow completes without hanging

---

## Phase 4: Lambda CI/CD Workflow (1.5 hours)

### 🚀 Task 4.1: Create Lambda Deployment Workflow
**File**: `.github/workflows/lambda-deploy.yml` (new file)

**What You'll Learn**:
- Docker build in GitHub Actions
- ECR (Elastic Container Registry)
- Lambda function deployment

**Create the workflow**:

```yaml
name: Deploy Certificate Lambda

on:
  push:
    paths:
      - 'clouds/aws/global/certificate-management/lambda/**'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-2

      - name: Get AWS account ID
        id: account
        run: echo "account_id=$(aws sts get-caller-identity --query Account --output text)" >> $GITHUB_OUTPUT

      - name: Log in to Amazon ECR
        run: |
          aws ecr get-login-password --region us-east-2 | \
            docker login --username AWS --password-stdin \
            ${{ steps.account.outputs.account_id }}.dkr.ecr.us-east-2.amazonaws.com

      - name: Build Lambda Docker image
        working-directory: clouds/aws/global/certificate-management/lambda
        run: docker build -t certbot-lambda .

      - name: Tag and push to ECR
        run: |
          REPO_URI=${{ steps.account.outputs.account_id }}.dkr.ecr.us-east-2.amazonaws.com/certbot-lambda
          docker tag certbot-lambda:latest $REPO_URI:latest
          docker tag certbot-lambda:latest $REPO_URI:${{ github.sha }}
          docker push $REPO_URI:latest
          docker push $REPO_URI:${{ github.sha }}

      - name: Update Lambda function
        run: |
          aws lambda update-function-code \
            --function-name certbot-renewal \
            --image-uri ${{ steps.account.outputs.account_id }}.dkr.ecr.us-east-2.amazonaws.com/certbot-lambda:latest \
            --region us-east-2
```

**Success Criteria**: Lambda deployment workflow created

---

## Phase 5: Documentation (3-4 hours)

### 📚 Task 5.1: Expand README.md
**File**: `README.md`

**Target**: 150-200 lines with comprehensive overview

**Sections to add**:
1. Project overview and learning journey
2. Multi-domain management (missingtable.com + qualityplaybook.dev)
3. Belt progression status
4. Quick start
5. Repository structure
6. Technologies used
7. Current monthly costs
8. Links to detailed docs

**Success Criteria**: Professional README that explains the project

---

### 📖 Task 5.2: Create Getting Started Guide
**File**: `docs/guides/getting-started.md`

**What to include**:
- Prerequisites with versions
- AWS account setup
- DigitalOcean account setup
- Clone and configure
- Variable configuration
- Initial deployment walkthrough
- Verification steps

**Success Criteria**: New user can follow guide to deploy

---

### 🏗️ Task 5.3: Create Architecture Overview
**File**: `docs/architecture/overview.md`

**What to include**:
- High-level system diagram
- Multi-cloud strategy rationale
- Certificate management architecture (dual-destination)
- State management approach
- CI/CD pipeline design
- Cost comparison tables

**Success Criteria**: Clear explanation of system design

---

## 📝 Commit Strategy

**After each phase**:
```bash
git add .
git status  # Always review!
git commit -m "Phase X: [description]"
git push origin public-repo-prep
```

**Final PR**:
```bash
gh pr create --title "Prepare repository for public release" \
  --body "Implements full preparation plan for making repository public:

- ✅ Phase 1: Security fixes and ACM integration
- ✅ Phase 2: S3 remote state backend
- ✅ Phase 3: Working GitHub Actions workflows
- ✅ Phase 4: Lambda CI/CD automation
- ✅ Phase 5: Comprehensive documentation

Repository is now ready for public release with:
- No personal information exposed
- Working CI/CD pipeline
- Professional documentation
- Multi-cloud certificate management"
```

---

## 🎓 Learning Checkpoints

After each phase, ask yourself:
1. **What did I learn?** → Add to `docs/decisions-log.md`
2. **What surprised me?** → Document the gotcha
3. **Would this work for someone else?** → Test your docs

---

## 🏆 Success Criteria - Public Release Ready

- [ ] No secrets or personal info in code
- [ ] CI/CD workflows run without manual intervention
- [ ] New user can clone and deploy from documentation
- [ ] Certificate management works for both DOKS and future EKS
- [ ] Professional README and documentation
- [ ] MIT License in place

**When all checked** → Make repository public! 🎉
