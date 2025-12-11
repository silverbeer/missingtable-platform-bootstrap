# Lambda Function: Certificate Management

This Lambda function manages TLS certificates using certbot and Route 53 DNS validation.

## Local Testing

### Prerequisites

1. **Install dependencies**:
   ```bash
   cd clouds/aws/global/certificate-management/lambda
   uv sync --python 3.13
   ```

2. **AWS Credentials**: Configure AWS credentials (via `~/.aws/credentials` or environment variables)
   - Needs: `secretsmanager:GetSecretValue`, `secretsmanager:PutSecretValue`, `secretsmanager:CreateSecret`
   - Needs: Route 53 access for certbot DNS-01 challenge

### Testing Options

#### 1. Dry Run (Recommended for First Test)

Tests the handler logic without actually running certbot or updating secrets:

```bash
source .venv/bin/activate
python test_local.py missingtable.com --dry-run
```

**What it does:**
- ✅ Tests the handler flow
- ✅ Checks if certificate exists in Secrets Manager
- ✅ Mocks certbot execution
- ✅ Mocks secret storage
- ❌ Doesn't actually run certbot
- ❌ Doesn't update AWS Secrets Manager

#### 2. Check Only

Only checks if a certificate exists in Secrets Manager:

```bash
python test_local.py missingtable.com --check-only
```

Or use the dedicated command:

```bash
python test_local.py test-get-certificate missingtable.com
```

#### 3. Full Test (Real Execution)

⚠️ **Warning**: This will actually run certbot and update AWS Secrets Manager!

```bash
python test_local.py missingtable.com --email your-email@example.com
```

**Requirements:**
- Route 53 hosted zone for the domain
- AWS credentials with Route 53 write access
- Domain DNS properly configured

### Test Examples

```bash
# Dry run (safe, no changes)
python test_local.py missingtable.com --dry-run

# Check if certificate exists
python test_local.py test-get-certificate missingtable.com

# Full test with custom email
python test_local.py missingtable.com --email admin@missingtable.com

# Full test (uses default email from variables.tf)
python test_local.py missingtable.com
```

## Understanding the Test Output

### Success Output

```
🧪 Testing Lambda Handler Locally

┌─ Test Configuration ─────────────────────────┐
│ Domain: missingtable.com                     │
│ Email: silverbeer.io@gmail.com               │
│ Dry Run: True                                │
│ Check Only: False                            │
└──────────────────────────────────────────────┘

Invoking Lambda handler...

✅ Handler completed successfully!

┌─ Lambda Response ────────────────────────────┐
│ Status Code: 200                             │
│ Response Body:                               │
│ {                                            │
│   "message": "Certificate for missingtable.com is still valid", │
│   "domain": "missingtable.com"               │
│ }                                            │
└──────────────────────────────────────────────┘
```

### Error Output

If there's an error, you'll see:
- Error type and message
- Full traceback
- Exit code 1

## Troubleshooting

### "No module named 'handler'"

Make sure you're in the lambda directory:
```bash
cd clouds/aws/global/certificate-management/lambda
```

### AWS Credentials Error

Configure AWS credentials:
```bash
aws configure
# Or set environment variables:
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_DEFAULT_REGION=us-east-2
```

### Certbot Fails

If certbot fails during full test:
- Check Route 53 hosted zone exists
- Verify DNS is properly configured
- Check AWS IAM permissions for Route 53

## Lambda Deployment

Once tested locally, deploy to AWS Lambda:

1. Package the Lambda function
2. Create Lambda function resource in OpenTofu
3. Set up IAM role with required permissions
4. Configure environment variables if needed
