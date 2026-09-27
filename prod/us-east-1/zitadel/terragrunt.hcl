locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/zitadel.hcl")
  rds_common   = read_terragrunt_config("${get_repo_root()}/_common/rds.hcl")
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  env            = local.env_vars.locals.env
  region         = local.region_vars.locals.aws_region
  project        = local.project_vars.locals.project_name
  app_domain     = local.project_vars.locals.app_domain
  zitadel_config = local.env_vars.locals.zitadel
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

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "${local.project}-${local.env}.cluster-xxxxxxxxxxxx.${local.region}.rds.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "valkey" {
  config_path = "../valkey"

  mock_outputs = {
    primary_endpoint = "mock-valkey-primary.zitadel.svc.cluster.local"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "zitadel_secrets" {
  config_path = "../zitadel-secrets"

  mock_outputs = {
    masterkey              = "0000000000000000000000000000000mock"
    db_app_username        = "zitadel"
    db_app_password        = "mock-db-app-password"
    aurora_master_password = "mock-aurora-master-password-000000000"
    valkey_auth_token      = "mock-valkey-auth-token-0000000000000000"
    admin_password         = "mock-admin-password-00000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    acm_certificate_arn = "arn:aws:acm:${local.region}:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

# No outputs needed from eks-addons; this dependency only enforces apply
# ordering so the AWS Load Balancer Controller exists before the Zitadel
# Ingress (which relies on it) is created.
dependency "eks_addons" {
  config_path = "../eks-addons"

  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "${get_repo_root()}//_modules/zitadel-release"
}

# Generate the Helm/Kubernetes provider configuration as a root-module file.
# Providers must not be declared inside reusable child modules.
generate "helm_provider" {
  path      = "helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    data "aws_eks_cluster" "zitadel" {
      name = "${dependency.eks.outputs.cluster_name}"
    }

    provider "helm" {
      kubernetes {
        host                   = data.aws_eks_cluster.zitadel.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.zitadel.certificate_authority[0].data)

        exec {
          api_version = "client.authentication.k8s.io/v1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.region}"]
        }
      }
    }

    provider "kubernetes" {
      host                   = data.aws_eks_cluster.zitadel.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.zitadel.certificate_authority[0].data)

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
  atomic        = true

  masterkey             = dependency.zitadel_secrets.outputs.masterkey
  masterkey_secret_name = "zitadel-masterkey"

  # The "zitadel" namespace is created and owned by the ../valkey unit
  # (which this release also depends on via the Redis connection), so this
  # release doesn't try to create it a second time.
  create_namespace = false

  admin_password    = dependency.zitadel_secrets.outputs.admin_password
  db_app_password   = dependency.zitadel_secrets.outputs.db_app_password
  db_admin_password = dependency.zitadel_secrets.outputs.aurora_master_password
  redis_password    = dependency.zitadel_secrets.outputs.valkey_auth_token

  expose_ingress_hostname = true
  ingress_name            = local.common.locals.release_name

  values = [
    local.common.locals.base_values,
    <<-YAML
      replicaCount: ${local.zitadel_config.replica_count}

      zitadel:
        masterkeySecretName: zitadel-masterkey

        # Non-sensitive config -> rendered into the zitadel-config-yaml ConfigMap
        configmapConfig:
          ExternalDomain: ${local.app_domain}
          ExternalPort: 443
          ExternalSecure: true

          TLS:
            Enabled: false

          Database:
            postgres:
              Host: "${dependency.rds.outputs.cluster_endpoint}"
              Port: ${local.rds_common.locals.port}
              Database: ${local.rds_common.locals.database_name}
              User:
                Username: ${dependency.zitadel_secrets.outputs.db_app_username}
                SSL:
                  Mode: require
              Admin:
                Username: ${local.rds_common.locals.master_username}
                SSL:
                  Mode: require

          Caches:
            Connectors:
              Redis:
                Enabled: true
                Addr: "${dependency.valkey.outputs.primary_endpoint}:6379"
                # No TLS -- Valkey runs in-cluster (pod-to-pod traffic only),
                # same trust boundary as wp.lodge104.net's in-cluster
                # Memcached sub-chart.
                EnableTLS: false
                DbOffset: 10
            Instance:
              Connector: redis
              MaxAge: 1h
              LastUseAge: 10m
            Organization:
              Connector: redis
              MaxAge: 1h
              LastUseAge: 10m

          FirstInstance:
            Org:
              Human:
                UserName: ${local.zitadel_config.admin_username}
                FirstName: ${local.zitadel_config.admin_first_name}
                LastName: ${local.zitadel_config.admin_last_name}
                Email:
                  Address: ${local.zitadel_config.admin_email}
                  Verified: true
                PasswordChangeRequired: true

          Machine:
            Identification:
              Hostname:
                Enabled: true
              Webhook:
                Enabled: false

      ingress:
        enabled: true
        className: alb
        annotations:
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/target-type: ip
          alb.ingress.kubernetes.io/certificate-arn: "${dependency.acm.outputs.acm_certificate_arn}"
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
          alb.ingress.kubernetes.io/backend-protocol-version: HTTP2
          alb.ingress.kubernetes.io/healthcheck-path: /debug/healthz
          alb.ingress.kubernetes.io/group.name: ${local.project}-${local.env}
          alb.ingress.kubernetes.io/group.order: "10"
        hosts:
          - host: ${local.app_domain}
            paths:
              - path: /
                pathType: Prefix
        tls:
          - hosts:
              - ${local.app_domain}

      # Route /ui/v2/login/* to the login service (Next.js, HTTP/1). Uses
      # the same ALB group as the main Zitadel ingress so both share a
      # single ALB. group.order=1 gives this more-specific path rule a
      # lower ALB priority number than the catch-all / rule
      # (group.order=10), so it is evaluated first and wins before the
      # wildcard.
      login:
        ingress:
          enabled: true
          className: alb
          annotations:
            alb.ingress.kubernetes.io/scheme: internet-facing
            alb.ingress.kubernetes.io/target-type: ip
            alb.ingress.kubernetes.io/certificate-arn: "${dependency.acm.outputs.acm_certificate_arn}"
            alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
            alb.ingress.kubernetes.io/backend-protocol-version: HTTP1
            alb.ingress.kubernetes.io/healthcheck-path: /healthz
            alb.ingress.kubernetes.io/group.name: ${local.project}-${local.env}
            alb.ingress.kubernetes.io/group.order: "1"
          hosts:
            - host: ${local.app_domain}
              paths:
                - path: /ui/v2/login
                  pathType: Prefix
          tls:
            - hosts:
                - ${local.app_domain}
    YAML
  ]
}
