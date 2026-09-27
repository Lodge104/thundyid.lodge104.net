locals {
  apps_common  = read_terragrunt_config("${get_repo_root()}/_common/zitadel-apps.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env = local.env_vars.locals.env

  # "prod" uses the thundyid.lodge104.net zone directly; dev/test each get
  # their own delegated sub-zone. Matches the app_domain logic in
  # ../zitadel/terragrunt.hcl and ../acm/terragrunt.hcl.
  app_domain = local.env == "prod" ? local.project_vars.locals.app_domain : "${local.env}.${local.project_vars.locals.app_domain}"
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Depends on the zitadel Helm release both for the instance to exist and to
# read back the FirstInstance.Org.Machine bootstrap admin's PAT (admin_pat
# output), which authenticates the zitadel provider generated below.
dependency "zitadel" {
  config_path = "../zitadel"

  mock_outputs = {
    admin_pat = "mock-admin-pat-0000000000000000000000000000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${get_repo_root()}//_modules/zitadel-resources"
}

# Generate the ZITADEL provider configuration as a root-module file.
# Providers must not be declared inside reusable child modules. Uses the
# machine admin's Personal Access Token (access_token) rather than a human
# login, so this unit can apply non-interactively.
generate "zitadel_provider" {
  path      = "zitadel_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        zitadel = {
          source  = "zitadel/zitadel"
          version = "~> 3.0"
        }
      }
    }

    provider "zitadel" {
      domain       = "${local.app_domain}"
      port         = "443"
      insecure     = false
      access_token = "${dependency.zitadel.outputs.admin_pat}"
    }
  EOF
}

inputs = {
  org_name     = local.apps_common.locals.org_name
  project_name = local.apps_common.locals.project_name

  oidc_web_apps    = local.apps_common.locals.oidc_web_apps
  oidc_public_apps = local.apps_common.locals.oidc_public_apps
  api_apps         = local.apps_common.locals.api_apps
}
