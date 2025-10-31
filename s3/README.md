# S3 Media Storage with CloudFront and Route53

This Terraform configuration creates a complete media storage solution with:

- **S3 Bucket**: Secure storage for media files with versioning and encryption
- **CloudFront Distribution**: Global CDN for fast content delivery
- **Route53 DNS**: Custom domain integration (media.thundyid.lodge104.net)
- **ACM Certificate**: SSL/TLS certificate for HTTPS
- **IAM User**: Dedicated user with S3 access permissions

## Architecture

```
Internet → Route53 → CloudFront → S3 Bucket
                          ↓
                   ACM Certificate
                   (SSL/TLS)
```

## Features

- **Security**: 
  - S3 bucket with private access via CloudFront OAC
  - SSL/TLS certificate for HTTPS
  - IAM user with minimal required permissions
  
- **Performance**:
  - CloudFront CDN for global content delivery
  - Compression enabled
  - Caching optimized for media files
  
- **Cost Optimization**:
  - CloudFront PriceClass_100 (North America & Europe only)
  - S3 standard storage class
  - Minimal ACM certificate validation

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Route53 Hosted Zone** for `thundyid.lodge104.net` domain
3. **Terraform** installed and configured
4. **AWS CLI** configured with credentials

## Deployment

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Review the plan**:
   ```bash
   terraform plan
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply
   ```

4. **Verify deployment**:
   - Check CloudFront distribution status
   - Test media domain: https://media.thundyid.lodge104.net
   - Verify Route53 DNS resolution

## Configuration

### Variables (terraform.tfvars)

```hcl
aws_region      = "us-east-1"
environment     = "prod"
domain_name     = "thundyid.lodge104.net"
media_subdomain = "media.thundyid.lodge104.net"
bucket_name     = "thundyid-lodge104-media"
iam_username    = "media-access-user"
```

### Outputs

After deployment, you'll get:
- S3 bucket name and ARN
- CloudFront distribution details
- Custom domain URL
- IAM credentials (access key ID & secret key)

## Usage

### IAM User Credentials

The deployment creates an IAM user with the following permissions:
- `s3:GetObject` - Download files
- `s3:PutObject` - Upload files
- `s3:DeleteObject` - Delete files
- `s3:ListBucket` - List bucket contents

Retrieve the credentials:
```bash
# Access Key ID (public)
terraform output iam_access_key_id

# Secret Access Key (sensitive)
terraform output -raw iam_secret_access_key
```

### Uploading Files

Using AWS CLI:
```bash
aws s3 cp file.jpg s3://thundyid-lodge104-media/images/
```

Using the IAM user credentials:
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
aws s3 cp file.jpg s3://thundyid-lodge104-media/images/
```

### Accessing Files

Files uploaded to S3 will be available via:
- **Direct S3 URL**: `https://thundyid-lodge104-media.s3.amazonaws.com/images/file.jpg`
- **CloudFront CDN**: `https://media.thundyid.lodge104.net/images/file.jpg` *(recommended)*

## Security Notes

1. **S3 Bucket**: Not publicly accessible, only via CloudFront
2. **IAM User**: Minimal permissions for S3 operations only
3. **SSL/TLS**: HTTPS enforced via CloudFront
4. **Credentials**: Store IAM credentials securely (use secrets manager in production)

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Warning**: This will permanently delete the S3 bucket and all its contents!

## Cost Considerations

- **S3 Storage**: Pay for storage used
- **CloudFront**: Pay for data transfer and requests
- **Route53**: Minimal cost for DNS queries
- **ACM Certificate**: Free for AWS resources
- **No EC2 instances**: Serverless architecture keeps costs low

## Troubleshooting

### Certificate Validation
If certificate validation fails:
1. Ensure Route53 hosted zone exists
2. Check DNS propagation
3. Wait up to 30 minutes for validation

### CloudFront Distribution
- Initial deployment takes 15-20 minutes
- Distribution must be "Deployed" status before use
- Changes take 5-10 minutes to propagate

### Domain Resolution
Test DNS resolution:
```bash
nslookup media.thundyid.lodge104.net
dig media.thundyid.lodge104.net
```