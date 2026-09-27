variable "org_name" {
  description = "Name of the ZITADEL organization these resources are created under. A dedicated org keeps the Auth0-migrated applications separate from the instance's default org."
  type        = string
  default     = "Occoneechee Lodge"
}

variable "is_default_org" {
  description = "Whether this org should be set as the instance's default org. Leave false -- the instance's own bootstrap org (created by FirstInstance) should remain default."
  type        = bool
  default     = false
}

variable "project_name" {
  description = "Name of the ZITADEL project all migrated applications are grouped under."
  type        = string
  default     = "Auth0 Migration"
}

# ---------------------------------------------------------------------------
# Application catalogs. Each map key is a stable internal identifier (used
# as the Terraform resource instance key); values configure the resulting
# zitadel_application_oidc / zitadel_application_api resource. See
# _common/zitadel-apps.hcl for the populated catalog migrated from Auth0.
# ---------------------------------------------------------------------------

variable "oidc_web_apps" {
  description = "Confidential OIDC web applications (server-side apps holding a client secret). Rendered as zitadel_application_oidc resources with app_type=OIDC_APP_TYPE_WEB and auth_method_type=OIDC_AUTH_METHOD_TYPE_BASIC."
  type = map(object({
    name                      = string
    redirect_uris             = list(string)
    post_logout_redirect_uris = optional(list(string), [])
  }))
  default = {}
}

variable "oidc_public_apps" {
  description = "Public OIDC applications (no client secret -- PKCE-only). Rendered as zitadel_application_oidc resources with auth_method_type=OIDC_AUTH_METHOD_TYPE_NONE. app_type selects OIDC_APP_TYPE_USER_AGENT (SPA) or OIDC_APP_TYPE_WEB per entry."
  type = map(object({
    name                      = string
    app_type                  = string
    redirect_uris             = list(string)
    post_logout_redirect_uris = optional(list(string), [])
  }))
  default = {}
}

variable "api_apps" {
  description = "Machine-to-machine (API) applications, using only the client_credentials grant. Rendered as zitadel_application_api resources."
  type = map(object({
    name             = string
    auth_method_type = optional(string, "API_AUTH_METHOD_TYPE_BASIC")
  }))
  default = {}
}
