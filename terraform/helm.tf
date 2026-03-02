# -----------------------------------------------------------------------------
# Helm Releases — external-dns, AWS LB Controller, Zitadel
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller
# EKS Auto Mode installs this automatically, but we need to configure the
# service account with the IRSA role.  If Auto Mode's built-in controller
# is sufficient, this can be removed.
# -----------------------------------------------------------------------------

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.12.0"

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

  depends_on = [module.eks]
}

# -----------------------------------------------------------------------------
# external-dns — manages Route53 records from Ingress annotations
# -----------------------------------------------------------------------------

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.15.2"

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

  depends_on = [module.eks]
}

# -----------------------------------------------------------------------------
# Zitadel — Identity management platform
# -----------------------------------------------------------------------------

resource "helm_release" "zitadel" {
  name       = "zitadel"
  repository = "https://charts.zitadel.com"
  chart      = "zitadel"
  namespace  = kubernetes_namespace.zitadel.metadata[0].name
  version    = var.zitadel_chart_version

  timeout = 900

  values = [
    yamlencode({
      replicaCount = 2

      zitadel = {
        masterkeySecretName = kubernetes_secret.zitadel_masterkey.metadata[0].name
        configSecretName    = kubernetes_secret.zitadel_db_credentials.metadata[0].name

        configmapConfig = {
          ExternalDomain = var.domain_name
          ExternalPort   = 443
          ExternalSecure = true

          TLS = {
            Enabled = false
          }

          Database = {
            Postgres = {
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
                DBOffset  = 10
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
                UserName               = var.zitadel_admin_username
                FirstName              = var.zitadel_admin_first_name
                LastName               = var.zitadel_admin_last_name
                Email                  = var.zitadel_admin_email
                Password               = var.zitadel_admin_password
                PasswordChangeRequired = true
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
          "external-dns.alpha.kubernetes.io/hostname"          = var.domain_name
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

      login = {
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
            "external-dns.alpha.kubernetes.io/hostname"          = var.domain_name
          }
          hosts = [
            {
              host = var.domain_name
              paths = [
                {
                  path     = "/ui/v2/login"
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
      }

      podDisruptionBudget = {
        enabled      = true
        minAvailable = 1
      }
    })
  ]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.external_dns,
    kubernetes_secret.zitadel_db_credentials,
    kubernetes_secret.zitadel_cache_credentials,
    kubernetes_secret.zitadel_masterkey,
    module.aurora,
    module.elasticache,
  ]
}
