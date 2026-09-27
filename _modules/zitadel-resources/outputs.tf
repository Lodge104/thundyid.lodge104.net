output "org_id" {
  description = "ID of the ZITADEL organization created for migrated applications."
  value       = zitadel_org.migration.id
}

output "project_id" {
  description = "ID of the ZITADEL project created for migrated applications."
  value       = zitadel_project.migration.id
}

output "oidc_web_app_ids" {
  description = "Map of internal app key -> ZITADEL application ID, for confidential OIDC web applications."
  value       = { for k, v in zitadel_application_oidc.web : k => v.id }
}

output "oidc_web_app_client_ids" {
  description = "Map of internal app key -> generated OIDC client ID, for confidential OIDC web applications."
  value       = { for k, v in zitadel_application_oidc.web : k => v.client_id }
  sensitive   = true
}

output "oidc_web_app_client_secrets" {
  description = "Map of internal app key -> generated OIDC client secret, for confidential OIDC web applications. Only populated on creation -- ZITADEL does not return secrets on subsequent reads."
  value       = { for k, v in zitadel_application_oidc.web : k => v.client_secret }
  sensitive   = true
}

output "oidc_public_app_ids" {
  description = "Map of internal app key -> ZITADEL application ID, for public (PKCE-only) OIDC applications."
  value       = { for k, v in zitadel_application_oidc.public : k => v.id }
}

output "oidc_public_app_client_ids" {
  description = "Map of internal app key -> generated OIDC client ID, for public (PKCE-only) OIDC applications."
  value       = { for k, v in zitadel_application_oidc.public : k => v.client_id }
  sensitive   = true
}

output "api_app_ids" {
  description = "Map of internal app key -> ZITADEL application ID, for machine-to-machine API applications."
  value       = { for k, v in zitadel_application_api.m2m : k => v.id }
}

output "api_app_client_ids" {
  description = "Map of internal app key -> generated client ID, for machine-to-machine API applications."
  value       = { for k, v in zitadel_application_api.m2m : k => v.client_id }
  sensitive   = true
}

output "api_app_client_secrets" {
  description = "Map of internal app key -> generated client secret, for machine-to-machine API applications. Only populated on creation."
  value       = { for k, v in zitadel_application_api.m2m : k => v.client_secret }
  sensitive   = true
}
