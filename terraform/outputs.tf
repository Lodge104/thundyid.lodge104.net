# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

# EKS
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.eks.cluster_version
}

# Aurora
output "aurora_cluster_endpoint" {
  description = "Aurora writer endpoint"
  value       = module.aurora.cluster_endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora reader endpoint"
  value       = module.aurora.cluster_reader_endpoint
}

output "aurora_master_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Aurora master password"
  value       = module.aurora.cluster_master_user_secret[0].secret_arn
}

# ElastiCache / Valkey
output "valkey_primary_endpoint" {
  description = "Valkey primary endpoint address"
  value       = module.elasticache.replication_group_primary_endpoint_address
}

# ACM
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the domain"
  value       = module.acm.acm_certificate_arn
}

# Application
output "zitadel_console_url" {
  description = "Zitadel admin console URL"
  value       = "https://${var.domain_name}/ui/console"
}

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

# Configure kubectl
output "configure_kubectl" {
  description = "Command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
