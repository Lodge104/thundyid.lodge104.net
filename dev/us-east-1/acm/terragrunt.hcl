locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/acm.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env = local.env_vars.locals.env

  # "prod" uses the thundyid.lodge104.net zone directly; dev/test each get
  # their own delegated sub-zone (dev.thundyid.lodge104.net /
  # test.thundyid.lodge104.net), mirroring wp.lodge104.net's per-env zone
  # delegation pattern. See global/route53-dev, global/route53-test, and
  # global/route53-env-delegation.
  app_domain     = local.env == "prod" ? local.project_vars.locals.app_domain : "${local.env}.${local.project_vars.locals.app_domain}"
  zone_unit_name = local.env == "prod" ? "route53-thundyid" : "route53-${local.env}"
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "zone" {
  config_path = "${get_repo_root()}/global/${local.zone_unit_name}"

  mock_outputs = {
    id = "Z1111111111111"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/acm/aws?version=5.1.1"
}

inputs = merge(
  local.common.locals,
  {
    domain_name = local.app_domain
    zone_id     = dependency.zone.outputs.id
  }
)
