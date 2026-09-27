locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/acm.hcl")
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  app_domain = local.project_vars.locals.app_domain
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "zone" {
  config_path = "${get_repo_root()}/global/route53-thundyid"

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
