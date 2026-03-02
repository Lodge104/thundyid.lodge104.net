# -----------------------------------------------------------------------------
# Aurora Serverless v2 (PostgreSQL) — terraform-aws-modules/rds-aurora/aws
# -----------------------------------------------------------------------------

module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 10.0"

  name = "${local.name}-db"

  engine         = "aurora-postgresql"
  engine_version = var.aurora_engine_version
  engine_mode    = "provisioned"

  # Serverless v2 scaling
  serverlessv2_scaling_configuration = {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  # Single serverless instance (staging/dev)
  cluster_instance_class = "db.serverless"
  instances = {
    writer = {}
  }

  # Database
  database_name   = var.aurora_database_name
  master_username = var.aurora_master_username

  # Let RDS manage the master password in Secrets Manager
  manage_master_user_password = true

  # Networking
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name

  # Security group — allow PostgreSQL from EKS nodes
  security_group_ingress_rules = {
    eks_nodes = {
      referenced_security_group_id = module.eks.node_security_group_id
      description                  = "PostgreSQL from EKS nodes"
    }
  }

  # Encryption
  storage_encrypted = true
  kms_key_id        = module.kms_rds.key_arn

  # Parameters
  cluster_parameter_group = {
    family = "aurora-postgresql16"
    parameters = [
      {
        name         = "rds.force_ssl"
        value        = "1"
        apply_method = "pending-reboot"
      }
    ]
  }

  # Staging settings
  skip_final_snapshot = true
  apply_immediately   = true

  # Monitoring
  cluster_monitoring_interval = 0

  tags = local.tags
}
