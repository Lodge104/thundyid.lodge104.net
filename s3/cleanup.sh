#!/bin/bash

# Cleanup S3 Media Storage Infrastructure
# This script destroys all created resources

set -e  # Exit on any error

echo "🗑️  S3 Media Storage Cleanup"
echo "============================"

# Warning message
echo "⚠️  WARNING: This will permanently delete:"
echo "   - S3 bucket and ALL its contents"
echo "   - CloudFront distribution"
echo "   - Route53 DNS records"
echo "   - SSL certificate"
echo "   - IAM user and credentials"

echo ""
read -p "🤔 Are you absolutely sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled."
    exit 1
fi

echo ""
read -p "🚨 Final confirmation - type 'DELETE' to proceed: " confirmation
if [ "$confirmation" != "DELETE" ]; then
    echo "❌ Cleanup cancelled."
    exit 1
fi

# Check if S3 bucket has objects and warn
bucket_name=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
if [ ! -z "$bucket_name" ]; then
    object_count=$(aws s3 ls s3://$bucket_name --recursive 2>/dev/null | wc -l || echo "0")
    if [ "$object_count" -gt 0 ]; then
        echo "⚠️  Bucket contains $object_count objects that will be deleted!"
        read -p "🤔 Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Cleanup cancelled."
            exit 1
        fi
    fi
fi

# Show what will be destroyed
echo "📋 Showing destruction plan..."
terraform plan -destroy

echo ""
read -p "🤔 Proceed with destruction? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled."
    exit 1
fi

# Destroy the infrastructure
echo "🗑️  Destroying infrastructure..."
terraform destroy -auto-approve

echo ""
echo "✅ Cleanup completed successfully!"
echo "================================"
echo "🗑️  All S3 Media Storage resources have been destroyed."
echo "💾 Terraform state files remain for reference."

# Optional: Remove state files
echo ""
read -p "🤔 Do you want to remove Terraform state files too? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f terraform.tfstate*
    echo "🗑️  Terraform state files removed."
fi

echo ""
echo "🎉 S3 Media Storage cleanup complete!"