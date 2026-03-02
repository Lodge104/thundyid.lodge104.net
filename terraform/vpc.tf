# -----------------------------------------------------------------------------
# VPC — terraform-aws-modules/vpc/aws
# -----------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = var.vpc_cidr
  azs  = var.availability_zones

  # Subnet layout: /20 gives ~4096 IPs per subnet
  private_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets   = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i + length(var.availability_zones))]
  database_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i + length(var.availability_zones) * 2)]

  # NAT Gateway — single for staging/dev to save cost
  enable_nat_gateway = true
  single_nat_gateway = true

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Database subnet group (used by Aurora and ElastiCache)
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # EKS Auto Mode subnet tags — required for automatic LB/node placement
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
