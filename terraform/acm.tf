# -----------------------------------------------------------------------------
# ACM Certificate — terraform-aws-modules/acm/aws
# -----------------------------------------------------------------------------

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 5.0"

  domain_name = var.domain_name

  zone_id = data.aws_route53_zone.main.zone_id

  # DNS validation (automatic via Route53)
  validation_method = "DNS"

  wait_for_validation = true

  tags = local.tags
}
