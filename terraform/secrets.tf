# -----------------------------------------------------------------------------
# Secrets — Random values + Kubernetes secrets bridge
# -----------------------------------------------------------------------------

# Zitadel 32-character masterkey
resource "random_password" "zitadel_masterkey" {
  length  = 32
  special = false
}

# Password for the Zitadel application DB user
resource "random_password" "zitadel_db_app_password" {
  length  = 32
  special = false
}

# Password for the Aurora master user (Terraform-managed, stable across apply cycles)
resource "random_password" "aurora_master_password" {
  length = 32
  # Avoid characters that cause shell/YAML quoting issues
  override_special = "!#$%&*()-_=+[]{}<>:?"
  special          = true
}

# Store masterkey in Secrets Manager for audit/recovery
module "secrets_manager_masterkey" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name                    = "${local.name}/zitadel-masterkey"
  description             = "Zitadel encryption masterkey"
  recovery_window_in_days = 0

  secret_string = random_password.zitadel_masterkey.result

  tags = local.tags
}

# Store Valkey auth token in Secrets Manager
module "secrets_manager_valkey" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name                    = "${local.name}/valkey-auth-token"
  description             = "Valkey auth token for Zitadel caching"
  recovery_window_in_days = 0

  secret_string = random_password.valkey_auth_token.result

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Kubernetes namespace
# -----------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "zitadel" {
  metadata {
    name = var.zitadel_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

# -----------------------------------------------------------------------------
# Kubernetes Secrets — bridge AWS secrets into K8s
# -----------------------------------------------------------------------------

# Zitadel masterkey secret
resource "kubernetes_secret_v1" "zitadel_masterkey" {
  metadata {
    name      = "zitadel-masterkey"
    namespace = kubernetes_namespace_v1.zitadel.metadata[0].name
  }

  data = {
    masterkey = random_password.zitadel_masterkey.result
  }

  type = "Opaque"
}

# Zitadel database credentials secret
resource "kubernetes_secret_v1" "zitadel_db_credentials" {
  metadata {
    name      = "zitadel-db-credentials"
    namespace = kubernetes_namespace_v1.zitadel.metadata[0].name
  }

  data = {
    "config.yaml" = yamlencode({
      Database = {
        Postgres = {
          User = {
            Password = random_password.zitadel_db_app_password.result
          }
          Admin = {
            Password = random_password.aurora_master_password.result
          }
        }
      }
    })
  }

  type = "Opaque"
}

# Zitadel cache credentials secret
resource "kubernetes_secret_v1" "zitadel_cache_credentials" {
  metadata {
    name      = "zitadel-cache-credentials"
    namespace = kubernetes_namespace_v1.zitadel.metadata[0].name
  }

  data = {
    "config.yaml" = yamlencode({
      Caches = {
        Connectors = {
          Redis = {
            Password = random_password.valkey_auth_token.result
          }
        }
      }
    })
  }

  type = "Opaque"
}

# -----------------------------------------------------------------------------
# Store Aurora master password in Secrets Manager for audit/recovery
# -----------------------------------------------------------------------------

module "secrets_manager_aurora_master" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name                    = "${local.name}/aurora-master-password"
  description             = "Aurora master password for ${local.name}-db"
  recovery_window_in_days = 0

  secret_string = random_password.aurora_master_password.result

  tags = local.tags
}

locals {
  aurora_master_password = random_password.aurora_master_password.result
}
