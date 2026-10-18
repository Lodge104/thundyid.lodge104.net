# Common EKS defaults – override in each env's terragrunt.hcl as needed.
# Module: terraform-aws-modules/eks/aws ~> 21.x (requires AWS provider >= 6.0).
#
# Zitadel runs on EKS Auto Mode -- AWS manages node pools, the AWS Load
# Balancer Controller equivalent networking, CoreDNS, etc. so there is no
# eks_managed_node_groups block here (unlike wp.lodge104.net's classic
# managed node groups). The aws-load-balancer-controller Helm chart is still
# installed explicitly in eks-addons because Auto Mode's built-in ALB
# integration expects it (Auto Mode does not itself run an Ingress
# controller for shared ALBs like this project uses).
locals {
  kubernetes_version = "1.37"

  # Stay on the standard-support upgrade train and let AWS auto-upgrade the
  # control plane at the end of standard support, instead of paying for
  # Extended Support ($0.60/cluster-hr vs. $0.10/cluster-hr -- roughly
  # $365/mo extra per cluster). The module/API default is EXTENDED.
  # https://aws.amazon.com/blogs/containers/amazon-eks-extended-support-for-kubernetes-versions-pricing/
  upgrade_policy = {
    support_type = "STANDARD"
  }

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Control plane log group (api/audit/authenticator) -- bound retention
  # cost instead of the module's 90-day default, and use the cheaper
  # Infrequent Access log class since these are for incident investigation,
  # not routine querying.
  cloudwatch_log_group_retention_in_days = 14
  cloudwatch_log_group_class             = "INFREQUENT_ACCESS"

  # EKS Auto Mode -- AWS manages compute via node pools instead of
  # eks_managed_node_groups.
  #
  # Cost optimization: the built-in "general-purpose" NodePool is fixed to
  # AMD64 instances only (AWS does not let you edit it, only enable or
  # disable it -- see https://docs.aws.amazon.com/eks/latest/best-practices/automode.html).
  # To actually reach Graviton's lower per-vCPU/GiB pricing, it is disabled
  # here in favor of a custom arm64-only "graviton" NodePool (generated in
  # eks-addons/terragrunt.hcl), per AWS's documented pattern:
  # https://aws.amazon.com/blogs/containers/maximize-amazon-eks-efficiency-how-auto-mode-graviton-and-spot-work-together/
  # "system" stays enabled -- it runs cluster-critical add-ons (CoreDNS,
  # etc.) and tolerates both architectures.
  compute_config = {
    enabled    = true
    node_pools = ["system"]
  }
}
