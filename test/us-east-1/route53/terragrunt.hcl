locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env    = local.env_vars.locals.env
  region = local.region_vars.locals.aws_region

  # "prod" uses the thundyid.lodge104.net zone directly; dev/test each get
  # their own delegated sub-zone. See global/route53-dev, global/route53-test,
  # and global/route53-env-delegation.
  app_domain     = local.env == "prod" ? local.project_vars.locals.app_domain : "${local.env}.${local.project_vars.locals.app_domain}"
  zone_unit_name = local.env == "prod" ? "route53-thundyid" : "route53-${local.env}"
  alb_zone_id    = local.region_vars.locals.alb_hosted_zone_id
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "zitadel" {
  config_path = "../zitadel"

  mock_outputs = {
    ingress_hostname = "mock-alb-123456789.${local.region}.elb.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "zone" {
  config_path  = "${get_repo_root()}/global/${local.zone_unit_name}"
  skip_outputs = true
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    name = local.app_domain
    records = {
      # ALB alias -- the ALB's own hosted zone ID is a fixed, region-specific
      # constant (see region.hcl), so an alias record can be created
      # directly here instead of waiting on external-dns to manage it.
      alb_ipv4 = {
        full_name = local.app_domain
        type      = "A"
        alias = {
          name    = dependency.zitadel.outputs.ingress_hostname
          zone_id = local.alb_zone_id
        }
      }
    }
  }
)
