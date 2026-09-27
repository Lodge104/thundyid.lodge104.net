output "masterkey" {
  description = "Zitadel encryption masterkey (32 bytes)."
  value       = random_password.masterkey.result
  sensitive   = true
}

output "masterkey_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the Zitadel masterkey."
  value       = aws_secretsmanager_secret.masterkey.arn
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

output "db_app_password_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the Zitadel application database role's credentials."
  value       = aws_secretsmanager_secret.db_app_password.arn
}

output "valkey_auth_token" {
  description = "In-cluster Valkey AUTH token."
  value       = random_password.valkey_auth_token.result
  sensitive   = true
}

output "valkey_auth_token_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the in-cluster Valkey AUTH token."
  value       = aws_secretsmanager_secret.valkey_auth_token.arn
}

output "aurora_master_password" {
  description = "Aurora PostgreSQL master (admin) password."
  value       = random_password.aurora_master_password.result
  sensitive   = true
}

output "aurora_master_password_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the Aurora master password."
  value       = aws_secretsmanager_secret.aurora_master_password.arn
}

output "admin_password" {
  description = "Initial Zitadel FirstInstance bootstrap admin password."
  value       = random_password.admin_password.result
  sensitive   = true
}

output "admin_credentials_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret holding the initial Zitadel admin username and password."
  value       = aws_secretsmanager_secret.admin_credentials.arn
}
