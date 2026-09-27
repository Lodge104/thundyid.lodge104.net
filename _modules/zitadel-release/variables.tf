variable "release_name" {
  description = "Helm release name."
  type        = string
}

variable "repository" {
  description = "Helm chart repository URL (e.g. https://charts.zitadel.com)."
  type        = string
}

variable "chart" {
  description = "Helm chart name."
  type        = string
}

variable "chart_version" {
  description = "Helm chart version to pin."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the release."
  type        = string
  default     = "zitadel"
}

variable "create_namespace" {
  description = "Create the Kubernetes namespace if it does not already exist."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Time in seconds to wait for Helm operations to complete."
  type        = number
  default     = 900
}

variable "wait" {
  description = "Wait until all Kubernetes resources are in a ready state."
  type        = bool
  default     = true
}

variable "atomic" {
  description = "Roll back the release automatically on failure."
  type        = bool
  default     = false
}

variable "values" {
  description = "List of raw YAML values strings (equivalent to -f values.yaml). Rendered in order; later entries override earlier ones."
  type        = list(string)
  default     = []
}

variable "masterkey" {
  description = "Zitadel's 32-byte encryption masterkey. Bridged into a Kubernetes Secret this module creates, so it can be referenced by name via the chart's zitadel.masterkeySecretName value."
  type        = string
  sensitive   = true
}

variable "masterkey_secret_name" {
  description = "Name of the Kubernetes Secret this module creates to hold the masterkey (data key \"masterkey\")."
  type        = string
  default     = "zitadel-masterkey"
}

variable "expose_ingress_hostname" {
  description = "Read back the hostname of the load balancer backing the release's main Ingress (e.g. an ALB DNS name) after install, for use by a downstream Route53 record."
  type        = bool
  default     = false
}

variable "ingress_name" {
  description = "Name of the Kubernetes Ingress to read the load balancer hostname from. Required when expose_ingress_hostname is true."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Sensitive Zitadel config, built into a `zitadel.secretConfig` Helm value
# by this module (via yamlencode) instead of being interpolated into a YAML
# heredoc in the calling terragrunt.hcl, which would otherwise leak these
# values into the rendered Helm value strings shown in `terraform plan`
# diffs. All four are still marked sensitive at the Terraform level; helm
# release *arguments* aren't rendered in plan diffs by the helm provider,
# but keeping the values out of the caller's plain-text `values` list is
# still the safer default.
# ---------------------------------------------------------------------------

variable "admin_password" {
  description = "Password for the FirstInstance bootstrap admin human user."
  type        = string
  sensitive   = true
}

variable "db_app_password" {
  description = "Password for the Zitadel application database role (Database.postgres.User.Password)."
  type        = string
  sensitive   = true
}

variable "db_admin_password" {
  description = "Password for the Aurora master/admin database role, used by Zitadel's setup job to create the application role and run migrations (Database.postgres.Admin.Password)."
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "AUTH token for the in-cluster Valkey/Redis cache connector (Caches.Connectors.Redis.Password)."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Bootstrap machine admin -- lets the zitadel-resources module (and its
# Terraform provider) authenticate to this instance without a human login.
# ---------------------------------------------------------------------------

variable "machine_admin_username" {
  description = "Username of the FirstInstance.Org.Machine bootstrap admin (configured via the Helm values, not by this module). When set, this module reads back the Personal Access Token the chart generates for that machine user, from the Kubernetes Secret named \"<username>-pat\", and exposes it via the admin_pat output. Leave null to skip (no machine admin configured)."
  type        = string
  default     = null
}
