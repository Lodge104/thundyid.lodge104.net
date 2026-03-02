# -----------------------------------------------------------------------------
# ElastiCache Valkey — terraform-aws-modules/elasticache/aws
#
# Zitadel requires a single-endpoint Redis/Valkey store (no cluster mode)
# with multiple DB indexes.  ElastiCache Serverless uses cluster mode
# internally (DB 0 only) and is incompatible.  A replication group with
# transit encryption satisfies the requirement.
# -----------------------------------------------------------------------------

resource "random_password" "valkey_auth_token" {
  length  = 32
  special = false
}

module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.0"

  replication_group_id = "${local.name}-valkey"

  engine         = "valkey"
  engine_version = var.valkey_engine_version
  node_type      = var.valkey_node_type

  # Single node for staging
  num_cache_clusters = 1

  # TLS in transit
  transit_encryption_enabled = true
  auth_token                 = random_password.valkey_auth_token.result

  maintenance_window = "sun:05:00-sun:07:00"
  apply_immediately  = true

  # Security Group
  vpc_id = module.vpc.vpc_id
  security_group_rules = {
    ingress_eks = {
      description                  = "Valkey from EKS nodes"
      referenced_security_group_id = module.eks.node_security_group_id
    }
  }

  # Subnet Group
  subnet_group_name        = "${local.name}-valkey"
  subnet_group_description = "Valkey subnet group"
  subnet_ids               = module.vpc.database_subnets

  # Parameter Group
  create_parameter_group      = true
  parameter_group_name        = "${local.name}-valkey"
  parameter_group_family      = "valkey7"
  parameter_group_description = "Valkey parameter group for Zitadel caching"
  parameters = [
    {
      name  = "latency-tracking"
      value = "yes"
    }
  ]

  tags = local.tags
}
