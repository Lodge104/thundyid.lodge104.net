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

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

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
