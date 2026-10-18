locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/eks-addons.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env     = local.env_vars.locals.env
  region  = local.region_vars.locals.aws_region
  project = local.project_vars.locals.project_name

  # external-dns should only manage records in the zone that actually
  # matches this env's Ingress hosts -- "prod" is the thundyid.lodge104.net
  # zone itself, dev/test are their own delegated sub-zones.
  domain = local.env == "prod" ? local.project_vars.locals.app_domain : "${local.env}.${local.project_vars.locals.app_domain}"
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name      = "${local.project}-${local.env}"
    cluster_endpoint  = "https://example.eks.amazonaws.com"
    cluster_version   = "1.33"
    oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/00000000000000000000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///aws-ia/eks-blueprints-addons/aws?version=1.24.3"
}

# Generate the Helm/Kubernetes provider configuration as a root-module file.
# Providers must not be declared inside reusable child modules.
generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    data "aws_eks_cluster" "eks_addons" {
      name = "${dependency.eks.outputs.cluster_name}"
    }

    provider "helm" {
      kubernetes = {
        host                   = data.aws_eks_cluster.eks_addons.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_addons.certificate_authority[0].data)

        exec = {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
        }
      }
    }

    provider "kubernetes" {
      host                   = data.aws_eks_cluster.eks_addons.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_addons.certificate_authority[0].data)

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
      }
    }
  EOF
}

# Custom Karpenter NodePool for AWS Graviton (arm64) instances.
#
# EKS Auto Mode's built-in "general-purpose" NodePool is fixed to AMD64 and
# is disabled in _common/eks.hcl, so this untainted custom pool is what
# every ordinary workload pod -- Zitadel, Valkey, and this unit's own
# aws-load-balancer-controller/external-dns -- actually schedules onto.
# All of those images publish multi-arch (amd64+arm64) manifests, so no
# pod-level nodeSelector/toleration is required for them to land here.
# Pattern: https://aws.amazon.com/blogs/containers/maximize-amazon-eks-efficiency-how-auto-mode-graviton-and-spot-work-together/
generate "graviton_node_pool" {
  path      = "graviton_node_pool.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    resource "kubernetes_manifest" "graviton_node_pool" {
      manifest = {
        apiVersion = "karpenter.sh/v1"
        kind       = "NodePool"
        metadata = {
          name = "graviton"
        }
        spec = {
          template = {
            spec = {
              nodeClassRef = {
                group = "eks.amazonaws.com"
                kind  = "NodeClass"
                name  = "default"
              }
              requirements = [
                { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
                { key = "eks.amazonaws.com/instance-category", operator = "In", values = ["c", "m", "r"] },
                { key = "eks.amazonaws.com/instance-generation", operator = "Gt", values = ["6"] },
                { key = "kubernetes.io/arch", operator = "In", values = ["arm64"] },
              ]
            }
          }
          disruption = {
            consolidationPolicy = "WhenEmptyOrUnderutilized"
            budgets = [
              { nodes = "10%" }
            ]
          }
        }
      }
    }
  EOF
}

inputs = merge(
  local.common.locals,
  {
    cluster_name      = dependency.eks.outputs.cluster_name
    cluster_endpoint  = dependency.eks.outputs.cluster_endpoint
    cluster_version   = dependency.eks.outputs.cluster_version
    oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn

    # EC2 metadata-based VPC auto-discovery fails for the controller, so pass
    # the VPC ID explicitly via helm values.
    aws_load_balancer_controller = {
      wait = true
      set = [
        {
          name  = "vpcId"
          value = dependency.vpc.outputs.vpc_id
        }
      ]
    }

    external_dns = {
      wait = true
      values = [
        yamlencode({
          provider   = { name = "aws" }
          policy     = "sync"
          registry   = "txt"
          txtOwnerId = "${local.project}-${local.env}"

          domainFilters = [local.domain]
        })
      ]
    }
  }
)
