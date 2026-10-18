output "masterkey" {
  description = "Zitadel encryption masterkey (32 bytes)."
  value       = random_password.masterkey.result
  sensitive   = true
}

output "db_app_username" {
  description = "Username of the Zitadel application database role."
  value       = var.db_app_username
}

output "db_app_password" {
  description = "Password for the Zitadel application database role."
  value       = random_password.db_app_password.result
  sensitive   = true
}

output "valkey_auth_token" {
  description = "In-cluster Valkey AUTH token."
  value       = random_password.valkey_auth_token.result
  sensitive   = true
}

output "aurora_master_password" {
  description = "Aurora PostgreSQL master (admin) password."
  value       = random_password.aurora_master_password.result
  sensitive   = true
}

output "admin_password" {
  description = "Initial Zitadel FirstInstance bootstrap admin password."
  value       = random_password.admin_password.result
  sensitive   = true
}

output "secret_arn" {
  description = "ARN of the single consolidated AWS Secrets Manager secret holding all Zitadel credentials (masterkey, app DB role, Valkey AUTH token, Aurora master password, initial admin credentials)."
  value       = aws_secretsmanager_secret.zitadel.arn
}
