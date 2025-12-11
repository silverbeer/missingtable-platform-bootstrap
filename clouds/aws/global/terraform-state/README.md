# Terraform State Management

This module creates the S3 bucket and DynamoDB table for storing Terraform state.

## What it creates

- **S3 Bucket**: `missingtable-terraform-state`
  - Versioning enabled (can recover old states)
  - Encryption enabled (AES256)
   - Public access blocked

- **DynamoDB Table**: `terraform-state-lock`
  - Pay-per-request billing
  - Used for state locking to prevent conflicts

## Bootstrap

This is bootstrapped WITHOUT remote state (chicken-egg problem).

```bash
cd clouds/aws/global/terraform-state
tofu init
tofu plan
tofu apply

After creation, all other modules use this bucket for remote state.