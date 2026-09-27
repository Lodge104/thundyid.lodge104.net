locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/vpc.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env         = local.env_vars.locals.env
  region      = local.region_vars.locals.aws_region
  project     = local.project_vars.locals.project_name
  cidr_prefix = local.env_vars.locals.vpc_cidr
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.13.0"
}

inputs = merge(
  local.common.locals,
  {
    name = "${local.project}-${local.env}"
    cidr = local.cidr_prefix

    azs              = ["${local.region}a", "${local.region}b"]
    private_subnets  = [cidrsubnet(local.cidr_prefix, 8, 1), cidrsubnet(local.cidr_prefix, 8, 2)]
    public_subnets   = [cidrsubnet(local.cidr_prefix, 8, 101), cidrsubnet(local.cidr_prefix, 8, 102)]
    database_subnets = [cidrsubnet(local.cidr_prefix, 8, 201), cidrsubnet(local.cidr_prefix, 8, 202)]

    # Additional tag (on top of the common role tags) required by the AWS
    # Load Balancer Controller to auto-discover subnets for this cluster.
    public_subnet_tags = merge(
      local.common.locals.public_subnet_tags,
      { "kubernetes.io/cluster/${local.project}-${local.env}" = "shared" }
    )
    private_subnet_tags = merge(
      local.common.locals.private_subnet_tags,
      { "kubernetes.io/cluster/${local.project}-${local.env}" = "shared" }
    )
  }
)
