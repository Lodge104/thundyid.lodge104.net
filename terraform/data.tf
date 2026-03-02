# -----------------------------------------------------------------------------
# Data sources
# -----------------------------------------------------------------------------

# Existing Route53 hosted zone for lodge104.net
data "aws_route53_zone" "main" {
  name         = var.route53_zone_name
  private_zone = false
}

# Current AWS caller identity (used for KMS policies, etc.)
data "aws_caller_identity" "current" {}

# Current AWS partition
data "aws_partition" "current" {}

# Available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}
