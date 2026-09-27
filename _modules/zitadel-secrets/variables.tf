variable "name_prefix" {
  description = "Prefix used for the AWS Secrets Manager secret names created by this module (e.g. \"net-lodge104-zitadel-prod\")."
  type        = string
}

variable "db_app_username" {
  description = "Username of the Zitadel application database role (created by Zitadel's setup job using the Aurora master/admin credentials)."
  type        = string
  default     = "zitadel"
}

variable "admin_username" {
  description = "Username of the FirstInstance bootstrap admin human user, used only to label the generated Secrets Manager secret -- the actual UserName Helm value is set from the same env.hcl config, not from this module."
  type        = string
  default     = "zitadel-admin"
}

variable "recovery_window_in_days" {
  description = "Number of days AWS Secrets Manager waits before permanently deleting a secret after destruction. Set to 0 to delete immediately."
  type        = number
  default     = 0

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0, or between 7 and 30."
  }
}
