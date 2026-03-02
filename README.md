# thundyid.lodge104.net

Self-hosted [Zitadel](https://zitadel.com/) identity management platform on AWS, deployed via Terraform.

## Architecture

| Component | AWS Service | terraform-aws-module |
|---|---|---|
| Networking | VPC, NAT Gateway | `terraform-aws-modules/vpc/aws` |
| Kubernetes | EKS Auto Mode | `terraform-aws-modules/eks/aws` |
| Database | Aurora Serverless v2 (PostgreSQL 16) | `terraform-aws-modules/rds-aurora/aws` |
| Caching | ElastiCache Valkey 7.2 | `terraform-aws-modules/elasticache/aws` |
| TLS Cert | ACM (DNS-validated) | `terraform-aws-modules/acm/aws` |
| Encryption | KMS | `terraform-aws-modules/kms/aws` |
| IAM (IRSA) | IAM Roles for Service Accounts | `terraform-aws-modules/iam/aws` |
| Secrets | Secrets Manager | `terraform-aws-modules/secrets-manager/aws` |
| DNS | Route53 (existing zone) | data source + external-dns |

**Key design decisions:**

- **EKS Auto Mode** — AWS fully manages compute, LB controller, CoreDNS, kube-proxy, and VPC CNI
- **Aurora Serverless v2** — scales down to 0.5 ACU; near-zero cost when idle
- **Valkey replication group** (not ElastiCache Serverless) — Zitadel requires single-endpoint Redis with multiple DB indexes (`DBOffset`), which is incompatible with cluster mode
- **ALB Ingress** via AWS Load Balancer Controller with TLS termination at the load balancer
- **external-dns** auto-manages Route53 alias records from Ingress annotations

## Prerequisites

- AWS account with permissions to create VPC, EKS, RDS, ElastiCache, ACM, KMS, IAM, Secrets Manager resources
- An existing Route53 hosted zone for `lodge104.net`
- Terraform >= 1.5.7
- AWS CLI configured (`aws configure` or env vars)
- `kubectl` and `helm` installed locally

## Quick Start

### Step 1: Bootstrap S3 Backend

The S3 backend stores Terraform state remotely with encryption, versioning, and state locking.

```bash
# Create S3 bucket and DynamoDB table for Terraform state
cd bootstrap
terraform init
terraform plan
terraform apply

# Save backend configuration
terraform output -json > ../backend-config.json
cd ../terraform
```

### Step 2: Initialize Terraform with S3 Backend

```bash
# Retrieve backend config values
BUCKET=$(cd ../bootstrap && terraform output -raw s3_bucket_name)
TABLE=$(cd ../bootstrap && terraform output -raw dynamodb_table_name)
REGION=$(cd ../bootstrap && terraform output -raw backend_config | jq -r '.region')

# Initialize with S3 backend
terraform init \
  -backend-config="bucket=$BUCKET" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=$REGION" \
  -backend-config="dynamodb_table=$TABLE" \
  -backend-config="encrypt=true"

# Answer "yes" when prompted to migrate state to S3
```

### Step 3: Deploy Infrastructure

```bash
# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (especially zitadel_admin_password)

# Review the plan
terraform plan

# Deploy
terraform apply

# Configure kubectl
$(terraform output -raw configure_kubectl)

# Watch Zitadel pods come up
kubectl -n zitadel get pods --watch
```

## Post-Deployment

1. **Verify pods**: `kubectl -n zitadel get pods` — wait for init/setup jobs to complete and deployment pods to be `Running`
2. **Check ingress**: `kubectl -n zitadel get ingress` — confirm ALB is provisioned
3. **DNS propagation**: `nslookup thundyid.lodge104.net` — verify DNS resolves to ALB
4. **Access console**: Open `https://thundyid.lodge104.net/ui/console`
5. **Login**: Use credentials from `terraform.tfvars` (`admin` / your password), change password on first login

## Project Structure

```
terraform/
├── main.tf               # Provider configuration (AWS, K8s, Helm)
├── versions.tf           # Terraform and provider version constraints
├── variables.tf          # Input variables
├── outputs.tf            # Output values
├── data.tf               # Data sources (Route53 zone, caller identity)
├── vpc.tf                # VPC, subnets, NAT Gateway
├── kms.tf                # KMS keys for EKS and Aurora encryption
├── eks.tf                # EKS Auto Mode cluster
├── aurora.tf             # Aurora Serverless v2 PostgreSQL cluster
├── elasticache.tf        # ElastiCache Valkey replication group
├── acm.tf                # ACM TLS certificate
├── irsa.tf               # IAM Roles for Service Accounts
├── secrets.tf            # Random passwords, K8s Secrets
├── db_setup.tf           # Post-provisioning DB user creation
├── helm.tf               # Helm releases (LB Controller, external-dns, Zitadel)
└── terraform.tfvars.example  # Example variable values
```

## Estimated Cost (Staging/Dev)

| Resource | Approximate Monthly Cost |
|---|---|
| EKS cluster | ~$73 (control plane) |
| EKS Auto Mode nodes | ~$30-60 (t3.medium equivalent, scales to demand) |
| Aurora Serverless v2 (0.5 ACU min) | ~$22-44 |
| ElastiCache Valkey (cache.t4g.micro) | ~$9 |
| NAT Gateway | ~$32 + data |
| ALB | ~$16 + data |
| Route53, ACM, KMS | < $5 |
| **Total** | **~$200-250/month** |

## Teardown

```bash
cd terraform
terraform destroy
```
