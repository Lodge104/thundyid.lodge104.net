# Delegated hosted zone for test.thundyid.lodge104.net (analogous to
# wp.lodge104.net/global/route53-test). Test is a full replica of prod's
# architecture but reachable under its own env-prefixed subdomain since it
# runs a separate ALB/cert from prod.
locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53.hcl")
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  app_domain = local.project_vars.locals.app_domain
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    create_zone   = true
    name          = "test.${local.app_domain}"
    enable_dnssec = true
    records       = {}
  }
)
