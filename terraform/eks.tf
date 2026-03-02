# -----------------------------------------------------------------------------
# EKS Auto Mode — terraform-aws-modules/eks/aws
# -----------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  # EKS Auto Mode — AWS manages node pools, LB controller, CoreDNS, etc.
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  # Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Endpoints
  endpoint_public_access  = true
  endpoint_private_access = true

  # Cluster creator gets admin access for bootstrapping
  enable_cluster_creator_admin_permissions = true

  # KMS encryption for Kubernetes secrets
  create_kms_key = false
  encryption_config = {
    provider_key_arn = module.kms_eks.key_arn
    resources        = ["secrets"]
  }

  tags = local.tags
}
