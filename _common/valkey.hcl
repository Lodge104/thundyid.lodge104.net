# Common in-cluster Valkey (Bitnami Helm chart) defaults – override in each
# env's terragrunt.hcl as needed.
#
# Zitadel requires a single-endpoint Redis/Valkey store (no cluster mode)
# with multiple DB indexes selected via DBOffset. Rather than a managed
# ElastiCache service, Valkey runs in-cluster via this chart -- the same
# cost-optimization pattern wp.lodge104.net uses for its cache layer
# (in-cluster Bitnami Memcached sub-chart instead of managed ElastiCache).
# Source: https://artifacthub.io/packages/helm/bitnami/valkey
locals {
  chart         = "valkey"
  repository    = "oci://registry-1.docker.io/bitnamicharts"
  chart_version = "6.3.3"

  # release_name intentionally contains the chart name ("valkey") so the
  # Bitnami common library's fullname template collapses to just the
  # release name (release name already contains chart name) instead of
  # "<release>-valkey" -- keeps the primary Service's DNS name short and
  # predictable: "<release_name>-primary.<namespace>.svc.cluster.local".
  release_name = "valkey"
  namespace    = "zitadel"

  # Kubernetes Secret (bridged from the Terraform-managed auth token in
  # _modules/zitadel-secrets) that the chart's auth.existingSecret value
  # references, instead of letting the chart generate/store its own.
  auth_secret_name = "valkey-auth"
  auth_secret_key  = "valkey-password"

  # ---------------------------------------------------------------------------
  # Base Helm values applied to all environments. No TLS -- traffic stays
  # inside the cluster network (pod-to-pod), same trust boundary as
  # wp.lodge104.net's in-cluster Memcached sub-chart.
  # ---------------------------------------------------------------------------
  base_values = <<-YAML
    architecture: standalone

    auth:
      enabled: true

    primary:
      persistence:
        enabled: true
        size: 2Gi
      resourcesPreset: small

    networkPolicy:
      enabled: true
  YAML
}
