# Common EKS addons (via aws-ia/eks-blueprints-addons) defaults – override in
# each env's terragrunt.hcl as needed.
#
# EKS Auto Mode already provides CoreDNS, kube-proxy, vpc-cni and its own
# load-balancing integration for Auto Mode node pools, but the shared ALB
# Ingress pattern used across this project (annotations-driven, shared with
# other Lodge104 apps' ALBs) still relies on the community AWS Load Balancer
# Controller, so it is installed explicitly here, same as wp.lodge104.net.
locals {
  enable_aws_load_balancer_controller = true

  enable_external_dns = true
}
