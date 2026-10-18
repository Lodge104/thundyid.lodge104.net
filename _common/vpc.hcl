# Common VPC defaults – override in each env's terragrunt.hcl as needed.
locals {
  # NAT Gateway removed entirely -- cost optimization mirroring
  # wp.lodge104.net's issue #32 pattern. EKS worker nodes now run in the
  # public subnets (see _common/eks.hcl / eks/terragrunt.hcl) with
  # security-group-scoped inbound access instead of routing egress through
  # a NAT Gateway. The database subnets (RDS) stay fully private and never
  # needed NAT in the first place.
  enable_nat_gateway = false

  # Required so instances placed in the public subnets (EKS nodes) get a
  # public IP at launch without a NAT Gateway providing egress.
  map_public_ip_on_launch = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  # Bound the flow log CloudWatch Logs group's storage cost -- default
  # (module) behavior retains logs indefinitely.
  flow_log_cloudwatch_log_group_retention_in_days = 14

  # Subnet tags required for EKS auto-discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  create_database_subnet_group = true
}
