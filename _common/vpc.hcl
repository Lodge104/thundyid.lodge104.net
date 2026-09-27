# Common VPC defaults – override in each env's terragrunt.hcl as needed.
locals {
  enable_nat_gateway   = true
  single_nat_gateway   = true
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
