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

# Store masterkey in Secrets Manager for audit/recovery
module "secrets_manager_masterkey" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name        = "${local.name}/zitadel-masterkey"
  description = "Zitadel encryption masterkey"

  secret_string = random_password.zitadel_masterkey.result

  tags = local.tags
}

# Store Valkey auth token in Secrets Manager
module "secrets_manager_valkey" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  name        = "${local.name}/valkey-auth-token"
  description = "Valkey auth token for Zitadel caching"

  secret_string = random_password.valkey_auth_token.result

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Kubernetes namespace
# -----------------------------------------------------------------------------

resource "kubernetes_namespace" "zitadel" {
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
resource "kubernetes_secret" "zitadel_masterkey" {
  metadata {
    name      = "zitadel-masterkey"
    namespace = kubernetes_namespace.zitadel.metadata[0].name
  }

  data = {
    masterkey = random_password.zitadel_masterkey.result
  }

  type = "Opaque"
}

# Zitadel database credentials secret
resource "kubernetes_secret" "zitadel_db_credentials" {
  metadata {
    name      = "zitadel-db-credentials"
    namespace = kubernetes_namespace.zitadel.metadata[0].name
  }

  data = {
    "config.yaml" = yamlencode({
      Database = {
        Postgres = {
          User = {
            Password = random_password.zitadel_db_app_password.result
          }
          Admin = {
            Password = data.aws_secretsmanager_secret_version.aurora_master.secret_string
          }
        }
      }
    })
  }

  type = "Opaque"
}

# Zitadel cache credentials secret
resource "kubernetes_secret" "zitadel_cache_credentials" {
  metadata {
    name      = "zitadel-cache-credentials"
    namespace = kubernetes_namespace.zitadel.metadata[0].name
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
# Lookup Aurora master password from Secrets Manager (managed by RDS)
# -----------------------------------------------------------------------------

data "aws_secretsmanager_secret" "aurora_master" {
  arn = module.aurora.cluster_master_user_secret[0].secret_arn
}

data "aws_secretsmanager_secret_version" "aurora_master" {
  secret_id = data.aws_secretsmanager_secret.aurora_master.id
}

# Extract the password from the JSON secret
locals {
  aurora_master_password = jsondecode(data.aws_secretsmanager_secret_version.aurora_master.secret_string)["password"]
}
