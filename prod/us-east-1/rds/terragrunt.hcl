locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/rds.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  region  = local.region_vars.locals.aws_region
  project = local.project_vars.locals.project_name
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id           = "vpc-00000000000000000"
    database_subnets = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_primary_security_group_id = "sg-00000000000000001"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "zitadel_secrets" {
  config_path = "../zitadel-secrets"

  mock_outputs = {
    aurora_master_password = "mock-aurora-master-password-000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/rds-aurora/aws?version=9.3.0"
}

inputs = merge(
  local.common.locals,
  {
    name = "${local.project}-${local.env}"

    master_password_wo         = dependency.zitadel_secrets.outputs.aurora_master_password
    master_password_wo_version = 1

    serverlessv2_scaling_configuration = local.env_vars.locals.rds_scaling
    instances                          = local.env_vars.locals.rds_instances

    db_subnet_group_name   = "${local.project}-${local.env}"
    subnets                = dependency.vpc.outputs.database_subnets
    vpc_id                 = dependency.vpc.outputs.vpc_id
    vpc_security_group_ids = [] # attach a dedicated Aurora SG

    security_group_rules = {
      eks_ingress = {
        description              = "PostgreSQL from EKS Auto Mode nodes"
        source_security_group_id = dependency.eks.outputs.cluster_primary_security_group_id
      }
    }

    deletion_protection = true
    skip_final_snapshot = false
  }
)
