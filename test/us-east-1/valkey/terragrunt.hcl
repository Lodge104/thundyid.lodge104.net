locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/valkey.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  region  = local.region_vars.locals.aws_region
  project = local.project_vars.locals.project_name
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name = "${local.project}-${local.env}"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "zitadel_secrets" {
  config_path = "../zitadel-secrets"

  mock_outputs = {
    valkey_auth_token = "mock-valkey-auth-token-0000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

# No outputs needed from eks-addons; this dependency only enforces apply
# ordering so networkPolicy support (via the VPC CNI's NetworkPolicy
# enforcement, part of EKS Auto Mode) and the cluster's core add-ons exist
# before this release installs.
dependency "eks_addons" {
  config_path = "../eks-addons"

  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${get_repo_root()}//_modules/valkey-release"
}

# Generate the Helm/Kubernetes provider configuration as a root-module file.
# Providers must not be declared inside reusable child modules.
generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    data "aws_eks_cluster" "valkey" {
      name = "${dependency.eks.outputs.cluster_name}"
    }

    provider "helm" {
      kubernetes {
        host                   = data.aws_eks_cluster.valkey.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.valkey.certificate_authority[0].data)

        exec {
          api_version = "client.authentication.k8s.io/v1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
        }
      }
    }

    provider "kubernetes" {
      host                   = data.aws_eks_cluster.valkey.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.valkey.certificate_authority[0].data)

      exec {
        api_version = "client.authentication.k8s.io/v1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
      }
    }
  EOF
}

inputs = {
  release_name  = local.common.locals.release_name
  repository    = local.common.locals.repository
  chart         = local.common.locals.chart
  chart_version = local.common.locals.chart_version
  namespace     = local.common.locals.namespace

  # This unit owns creation of the shared "zitadel" namespace; the zitadel
  # Helm release (../zitadel) depends on this unit and sets its own
  # create_namespace to false to avoid both units racing to create (and
  # then fighting over ownership of) the same Namespace resource.
  create_namespace = true

  auth_password    = dependency.zitadel_secrets.outputs.valkey_auth_token
  auth_secret_name = local.common.locals.auth_secret_name
  auth_secret_key  = local.common.locals.auth_secret_key

  values = [local.common.locals.base_values]
}
