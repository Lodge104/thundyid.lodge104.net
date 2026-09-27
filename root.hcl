# -----------------------------------------------------------------------------
# Root Terragrunt configuration
# Defines remote state backend and shared provider/inputs for all modules.
# Mirrors the structure used in Lodge104/wp.lodge104.net.
# -----------------------------------------------------------------------------

# Note: env/region locals are NOT read here because find_in_parent_folders is
# evaluated in the root file's own directory context and cannot traverse into
# child env/region trees. Each child module reads those files in its own locals.

locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))
  project_name = local.project_vars.locals.project_name
}

# ---------------------------------------------------------------------------
# Remote state – all envs share one S3 bucket, keys are scoped by path.
# ---------------------------------------------------------------------------
remote_state {
  backend = "s3"
  config = {
    bucket       = "${local.project_name}-terraform-state"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ---------------------------------------------------------------------------
# Provider – generated into every module directory at plan/apply time.
# ---------------------------------------------------------------------------
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.9.0"
    }

    # Region and tags are set via the AWS_DEFAULT_REGION env var and the
    # inputs passed by each child module's terragrunt.hcl.
    provider "aws" {}
  EOF
}
