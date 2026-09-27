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
  kubernetes_version = "1.33"

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # EKS Auto Mode -- AWS manages compute via node pools instead of
  # eks_managed_node_groups.
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }
}
