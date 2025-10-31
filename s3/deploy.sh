#!/bin/bash

# Deploy S3 Media Storage with CloudFront and Route53
# This script deploys the complete media storage infrastructure

set -e  # Exit on any error

echo "🚀 Deploying S3 Media Storage Infrastructure..."
echo "================================================"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "❌ terraform.tfvars not found!"
    echo "📝 Please create terraform.tfvars based on terraform.tfvars.example"
    exit 1
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Show deployment plan
echo "📋 Showing deployment plan..."
terraform plan

# Ask for confirmation
read -p "🤔 Do you want to proceed with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

# Apply the configuration
echo "🚀 Deploying infrastructure..."
terraform apply -auto-approve

echo ""
echo "✅ Deployment completed successfully!"
echo "================================================"

# Display important outputs
echo "📊 Important Information:"
echo "------------------------"
echo "🪣 S3 Bucket: $(terraform output -raw s3_bucket_name)"
echo "🌐 Media URL: $(terraform output -raw media_domain_url)"
echo "🚀 CloudFront ID: $(terraform output -raw cloudfront_distribution_id)"
echo "👤 IAM User: $(terraform output -raw iam_user_name)"
echo "🔑 Access Key ID: $(terraform output -raw iam_access_key_id)"

echo ""
echo "🔐 To get secret access key (sensitive):"
echo "terraform output -raw iam_secret_access_key"

echo ""
echo "⚠️  Important Notes:"
echo "- CloudFront distribution takes 15-20 minutes to fully deploy"
echo "- SSL certificate validation may take up to 30 minutes"
echo "- Store IAM credentials securely"
echo "- Test the media URL after CloudFront deployment completes"

echo ""
echo "🎉 S3 Media Storage is now ready!"