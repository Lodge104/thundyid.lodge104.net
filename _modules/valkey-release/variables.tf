variable "release_name" {
  description = "Helm release name."
  type        = string
}

variable "repository" {
  description = "Helm chart OCI repository URL (e.g. oci://registry-1.docker.io/bitnamicharts)."
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
}

variable "create_namespace" {
  description = "Create the Kubernetes namespace if it does not already exist. Set false when a sibling release (e.g. the main application) already manages it."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Time in seconds to wait for Helm operations to complete."
  type        = number
  default     = 300
}

variable "wait" {
  description = "Wait until all Kubernetes resources are in a ready state."
  type        = bool
  default     = true
}

variable "atomic" {
  description = "Roll back the release automatically on failure."
  type        = bool
  default     = true
}

variable "values" {
  description = "List of raw YAML values strings (equivalent to -f values.yaml). Rendered in order; later entries override earlier ones."
  type        = list(string)
  default     = []
}

variable "auth_password" {
  description = "AUTH password, bridged into a Kubernetes Secret this module creates so the chart can reference it by name via auth.existingSecret (keeps the plaintext value out of the rendered Helm values)."
  type        = string
  sensitive   = true
}

variable "auth_secret_name" {
  description = "Name of the Kubernetes Secret this module creates to hold the AUTH password."
  type        = string
}

variable "auth_secret_key" {
  description = "Key within the created Kubernetes Secret's data map that holds the password."
  type        = string
  default     = "password"
}

variable "primary_service_name" {
  description = "Name of the Kubernetes Service fronting the primary/standalone node, used to build the in-cluster endpoint output (defaults to \"<release_name>-primary\", matching the Bitnami chart's naming when release_name already contains \"valkey\")."
  type        = string
  default     = null
}
