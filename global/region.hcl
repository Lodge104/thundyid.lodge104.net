locals {
  aws_region = "us-east-1"

  # Region-specific constants that repeat across environments in this region.
  # AWS-published Route53 hosted zone ID for Application Load Balancers in
  # us-east-1 (constant per region, not a Terraform resource attribute).
  # https://docs.aws.amazon.com/general/latest/gr/elb.html
  alb_hosted_zone_id = "Z35SXDOTRQ7X7K"
}
