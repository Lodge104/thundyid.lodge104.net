# Common Aurora PostgreSQL Serverless v2 defaults – override in each env's
# terragrunt.hcl as needed.
# Zitadel requires PostgreSQL 14+; see
# https://zitadel.com/docs/self-hosting/manage/database/postgres
locals {
  engine               = "aurora-postgresql"
  engine_version       = "16.6"
  engine_mode          = "provisioned" # Serverless v2 uses provisioned mode with db.serverless instances
  family               = "aurora-postgresql16"
  major_engine_version = "16"

  port          = 5432
  database_name = "zitadel"

  # Terraform-managed master password (random_password, generated in
  # _modules/zitadel-secrets and passed in via master_password_wo) instead of
  # manage_master_user_password = true -- avoids a data-source race
  # condition reading the AWS-generated Secrets Manager secret back on
  # freshly created clusters, and lets the same value be reused directly by
  # the zitadel-release Helm values without an extra Secrets Manager lookup.
  master_username             = "zitadeladmin"
  manage_master_user_password = false

  backup_retention_period      = 7
  preferred_backup_window      = "03:00-06:00"
  preferred_maintenance_window = "mon:00:00-mon:03:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Enhanced monitoring disabled -- its per-instance CloudWatch cost wasn't
  # justified by active use. Performance Insights (free tier: 7-day
  # retention) remains enabled for query-level diagnostics.
  create_monitoring_role = false
  monitoring_interval    = 0

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = true
  apply_immediately          = false

  # Serverless v2 requires at least one instance of class db.serverless.
  instance_class = "db.serverless"

  # Force TLS connections -- Zitadel's Postgres SSL.Mode is set to "require"
  # in the helm-release values, so the server side must also enforce it.
  parameters = {
    "rds.force_ssl" = "1"
  }

  # Module defaults create_db_subnet_group to false (expects an existing
  # group); we want it created from the subnets/vpc_id we pass in.
  create_db_subnet_group = true
}
