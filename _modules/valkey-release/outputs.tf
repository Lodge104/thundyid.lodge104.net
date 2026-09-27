output "release_name" {
  description = "Helm release name."
  value       = helm_release.this.name
}

output "release_namespace" {
  description = "Kubernetes namespace of the Helm release."
  value       = helm_release.this.namespace
}

output "primary_endpoint" {
  description = "In-cluster DNS endpoint (host only, no port) of the Valkey primary/standalone Service."
  value       = "${coalesce(var.primary_service_name, "${var.release_name}-primary")}.${var.namespace}.svc.cluster.local"
}
