# Delegated hosted zone for thundyid.lodge104.net (analogous to
# wp.lodge104.net/global/route53-dev). Zitadel is a single-environment
# ("prod") service, so this zone hosts records directly rather than per-env
# subdomains.
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
    name          = local.app_domain
    enable_dnssec = true
    records       = {}
  }
)
