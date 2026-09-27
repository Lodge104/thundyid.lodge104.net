locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  project = local.project_vars.locals.project_name
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

terraform {
  source = "${get_repo_root()}//_modules/zitadel-secrets"
}

inputs = {
  name_prefix    = "${local.project}-${local.env}"
  admin_username = local.env_vars.locals.zitadel.admin_username
}
