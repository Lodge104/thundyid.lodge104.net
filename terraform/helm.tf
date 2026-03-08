# Helm Releases using Terraform Helm Provider

# Configure kubeconfig for Helm/Kubernetes access
# NOTE: This provisioner runs during apply, so the Helm provider initialization 
# may require pre-configured kubeconfig. You can pre-configure it by running:
#   aws eks update-kubeconfig --region <region> --name <cluster-name>
resource "null_resource" "helm_kubeconfig" {
  triggers = {
    cluster_name = module.eks.cluster_name
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
  }

  depends_on = [module.eks]
}

# AWS Load Balancer Controller via Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.12.0"
  wait       = true
  timeout    = 300

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      region      = var.aws_region
      vpcId       = module.vpc.vpc_id

      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.irsa_aws_lb_controller.iam_role_arn
        }
      }
    })
  ]

  depends_on = [module.eks, null_resource.helm_kubeconfig]
}

# external-dns via Helm
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.15.2"
  wait       = true
  timeout    = 300

  values = [
    yamlencode({
      provider = {
        name = "aws"
      }
      policy     = "sync"
      registry   = "txt"
      txtOwnerId = local.name

      domainFilters = [var.route53_zone_name]

      serviceAccount = {
        create = true
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.irsa_external_dns.iam_role_arn
        }
      }
    })
  ]

  depends_on = [helm_release.aws_load_balancer_controller]
}

# Zitadel via Helm
resource "helm_release" "zitadel" {
  name       = "zitadel"
  repository = "https://charts.zitadel.com"
  chart      = "zitadel"
  namespace  = kubernetes_namespace_v1.zitadel.metadata[0].name
  version    = "9.2.0"
  wait       = true
  timeout    = 900

  values = [
    yamlencode({
      replicaCount = 2

      zitadel = {
        # Reference our Terraform-managed masterkey secret (key: "masterkey")
        masterkeySecretName = kubernetes_secret_v1.zitadel_masterkey.metadata[0].name

        # Non-sensitive config → rendered into the zitadel-config-yaml ConfigMap
        configmapConfig = {
          ExternalDomain = var.domain_name
          ExternalPort   = 443
          ExternalSecure = true

          TLS = {
            Enabled = false
          }

          Database = {
            postgres = {
              Host     = module.aurora.cluster_endpoint
              Port     = 5432
              Database = var.aurora_database_name
              User = {
                Username = "zitadel"
                SSL = {
                  Mode = "require"
                }
              }
              Admin = {
                Username = var.aurora_master_username
                SSL = {
                  Mode = "require"
                }
              }
            }
          }

          Caches = {
            Connectors = {
              Redis = {
                Enabled   = true
                Addr      = "${module.elasticache.replication_group_primary_endpoint_address}:6379"
                EnableTLS = true
                DbOffset  = 10
              }
            }
            Instance = {
              Connector  = "redis"
              MaxAge     = "1h"
              LastUseAge = "10m"
            }
            Organization = {
              Connector  = "redis"
              MaxAge     = "1h"
              LastUseAge = "10m"
            }
          }

          FirstInstance = {
            Org = {
              Human = {
                UserName  = var.zitadel_admin_username
                FirstName = var.zitadel_admin_first_name
                LastName  = var.zitadel_admin_last_name
                Email = {
                  Address  = var.zitadel_admin_email
                  Verified = true
                }
                PasswordChangeRequired = true
              }
            }
          }

          Machine = {
            Identification = {
              Hostname = {
                Enabled = true
              }
              Webhook = {
                Enabled = false
              }
            }
          }
        }

        # Sensitive config → rendered into the zitadel-secrets-yaml Secret and mounted alongside the ConfigMap
        secretConfig = {
          FirstInstance = {
            Org = {
              Human = {
                Password = var.zitadel_admin_password
              }
            }
          }
          Database = {
            postgres = {
              User = {
                Password = random_password.zitadel_db_app_password.result
              }
              Admin = {
                Password = local.aurora_master_password
              }
            }
          }
          Caches = {
            Connectors = {
              Redis = {
                Password = random_password.valkey_auth_token.result
              }
            }
          }
        }
      }

      ingress = {
        enabled   = true
        className = "alb"
        annotations = {
          "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"              = "ip"
          "alb.ingress.kubernetes.io/certificate-arn"          = module.acm.acm_certificate_arn
          "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/backend-protocol-version" = "HTTP2"
          "alb.ingress.kubernetes.io/healthcheck-path"         = "/debug/healthz"
          "alb.ingress.kubernetes.io/group.name"               = local.name
        }
        hosts = [
          {
            host = var.domain_name
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
              }
            ]
          }
        ]
        tls = [
          {
            hosts = [var.domain_name]
          }
        ]
      }

      podDisruptionBudget = {
        enabled      = true
        minAvailable = 1
      }

      # Increase job deadlines (default 300s is not enough for fresh setup on Aurora Serverless v2)
      initJob = {
        activeDeadlineSeconds = 120
      }
      setupJob = {
        activeDeadlineSeconds = 300
        # Remove --init-projections=true (default): projection workers stuck in "started"
        # state from a previous killed run cause checkExec() to loop indefinitely.
        # Projections initialize normally when zitadel start runs.
        additionalArgs = []
        # bitnami/kubectl only publishes "latest" tag; the chart default computes "1.32"
        # from the K8s version which does not exist in the registry.
        machinekeyWriter = {
          image = {
            repository = "bitnami/kubectl"
            tag        = "latest"
          }
        }
      }

      # Mark login-client secret volume as optional so login pods can start even if the
      # PAT was not regenerated (e.g. on re-runs where machine user already exists in DB).
      # The login app will operate in degraded mode until the secret is populated.
      login = {
        extraVolumes = [
          {
            name = "login-client"
            secret = {
              defaultMode = 444
              secretName  = "login-client"
              optional    = true
            }
          }
        ]
      }
    })
  ]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.external_dns,
    kubernetes_secret_v1.zitadel_db_credentials,
    kubernetes_secret_v1.zitadel_cache_credentials,
    kubernetes_secret_v1.zitadel_masterkey,
    module.aurora,
    module.elasticache,
  ]
}

