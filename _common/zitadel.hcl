# Common Zitadel Helm chart defaults.
# Source: https://github.com/zitadel/zitadel-charts
locals {
  chart         = "zitadel"
  repository    = "https://charts.zitadel.com"
  chart_version = "9.2.0"
  release_name  = "zitadel"
  namespace     = "zitadel"

  # FirstInstance.Org.Machine bootstrap admin -- created alongside the human
  # admin (see FirstInstance.Org.Human in each env's zitadel/terragrunt.hcl)
  # so the zitadel-resources module's Terraform provider has a
  # non-interactive Personal Access Token to authenticate with, instead of
  # requiring a human login. The chart writes the PAT to a Kubernetes Secret
  # named "<machine_admin_username>-pat", which zitadel-release reads back
  # via its machine_admin_username input.
  machine_admin_username = "zitadel-terraform-admin"

  # ---------------------------------------------------------------------------
  # Base Helm values applied to all environments.
  # TLS is terminated at the ALB, so the pod-internal listener stays plain
  # HTTP (TLS.Enabled = false) -- see
  # https://zitadel.com/docs/self-hosting/deploy/kubernetes.
  # ---------------------------------------------------------------------------
  base_values = <<-YAML
    podDisruptionBudget:
      enabled: true
      minAvailable: 1

    # Increase job deadlines -- default 300s is not enough for a fresh setup
    # against Aurora Serverless v2 while it's scaling up from 0.
    initJob:
      activeDeadlineSeconds: 120
    setupJob:
      activeDeadlineSeconds: 300
      # Remove --init-projections=true (default): projection workers stuck
      # in "started" state from a previous killed run cause checkExec() to
      # loop indefinitely. Projections initialize normally when
      # `zitadel start` runs.
      additionalArgs: []
      # bitnami/kubectl only publishes a "latest" tag; the chart default
      # computes a tag like "1.33" from the K8s version, which does not
      # exist in the registry.
      machinekeyWriter:
        image:
          repository: bitnami/kubectl
          tag: latest

    # Mark the login-client secret volume as optional so login pods can
    # start even if the PAT was not regenerated (e.g. on re-runs where the
    # machine user already exists in the DB). The login app operates in
    # degraded mode until the secret is populated.
    login:
      extraVolumes:
        - name: login-client
          secret:
            defaultMode: 292
            secretName: login-client
            optional: true
  YAML
}
