output "release_name" {
  description = "Helm release name."
  value       = helm_release.this.name
}

output "release_namespace" {
  description = "Kubernetes namespace of the Helm release."
  value       = helm_release.this.namespace
}

output "release_status" {
  description = "Current status of the Helm release."
  value       = helm_release.this.status
}

output "ingress_hostname" {
  description = "Hostname of the load balancer backing the release's Ingress (e.g. an ALB DNS name), when `expose_ingress_hostname` is true. Null otherwise, or if the load balancer isn't provisioned yet."
  value       = try(data.kubernetes_ingress_v1.this[0].status[0].load_balancer[0].ingress[0].hostname, null)
}

output "admin_pat" {
  description = "Personal Access Token for the FirstInstance.Org.Machine bootstrap admin, when `machine_admin_username` is set. Used by the zitadel-resources module's Terraform provider to authenticate. Null if machine_admin_username was not set."
  value       = try(data.kubernetes_secret_v1.admin_pat[0].data["pat"], null)
  sensitive   = true
}
