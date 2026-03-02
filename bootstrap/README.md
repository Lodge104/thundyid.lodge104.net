# =============================================================================
# S3 Backend Bootstrap Guide
#
# This directory creates the AWS infrastructure for Terraform's S3 backend.
# =============================================================================

## Prerequisites

- AWS CLI configured (`aws configure` or env vars)
- Terraform >= 1.5.7

## Setup Steps

### 1. Bootstrap the S3 backend infrastructure

```bash
cd bootstrap

# Initialize (with local backend)
terraform init

# Review and apply
terraform plan
terraform apply

# Save the output values
terraform output -json > ../backend-config.json
```

### 2. Configure the main Terraform directory to use S3 backend

```bash
cd ../terraform

# Retrieve backend config from bootstrap outputs
BUCKET=$(cd ../bootstrap && terraform output -raw s3_bucket_name)
TABLE=$(cd ../bootstrap && terraform output -raw dynamodb_table_name)
REGION=$(cd ../bootstrap && terraform output -raw backend_config | jq -r '.region')

# Initialize with S3 backend configuration
terraform init \
  -backend-config="bucket=$BUCKET" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=$REGION" \
  -backend-config="dynamodb_table=$TABLE" \
  -backend-config="encrypt=true"
```

When prompted to migrate local state to S3, answer **yes**.

### 3. Verify backend is working

```bash
terraform state list
# Should show resources from the S3 backend
```

## Cleanup

To destroy the bootstrap infrastructure (including the S3 bucket and DynamoDB table):

```bash
cd bootstrap
terraform destroy
```

**Warning**: This will delete the S3 bucket containing your Terraform state. Only do this if you no longer need the infrastructure or have backed up the state.

## Backend Configuration Reference

The S3 backend stores:
- **Bucket**: `{project_name}-terraform-state-{account_id}`
- **Key**: `terraform.tfstate` (per environment)
- **Region**: From `aws_region` variable
- **Encryption**: Enabled (AES256)
- **Versioning**: Enabled (for state recovery)
- **Locking**: DynamoDB table for concurrent operation safety

## Troubleshooting

### Error: "Access Denied" when running `terraform init`

Ensure your AWS credentials have permissions to create and access S3 and DynamoDB resources.

### State is not migrating from local to S3

Manually move the state file:

```bash
export BUCKET=$(cd ../bootstrap && terraform output -raw s3_bucket_name)
export REGION=$(cd ../bootstrap && terraform output -raw backend_config | jq -r '.region')

aws s3 cp terraform.tfstate s3://$BUCKET/terraform.tfstate \
  --region $REGION \
  --sse AES256
```

Then verify: `terraform state list`
