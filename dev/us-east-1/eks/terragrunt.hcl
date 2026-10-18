locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/eks.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  region  = local.region_vars.locals.aws_region
  project = local.project_vars.locals.project_name
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    public_subnets  = ["subnet-00000000000000001", "subnet-00000000000000002"]
    private_subnets = ["subnet-00000000000000003", "subnet-00000000000000004"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=21.24.0"
}

inputs = merge(
  local.common.locals,
  {
    name = "${local.project}-${local.env}"

    vpc_id = dependency.vpc.outputs.vpc_id

    # Worker nodes run in the public subnets -- NAT Gateway removed from
    # the VPC (see _common/vpc.hcl). Nodes get a public IP
    # (map_public_ip_on_launch = true) and rely on security groups for
    # inbound restriction. The control plane ENIs stay on the private
    # subnets -- the control plane talks to the EKS service over the AWS
    # backbone, not through an internet gateway, so it never needed NAT.
    subnet_ids               = dependency.vpc.outputs.public_subnets
    control_plane_subnet_ids = dependency.vpc.outputs.private_subnets
  }
)
