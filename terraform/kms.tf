# -----------------------------------------------------------------------------
# KMS Keys — terraform-aws-modules/kms/aws
# -----------------------------------------------------------------------------

module "kms_eks" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.0"

  description = "${local.name} EKS secrets encryption key"
  key_usage   = "ENCRYPT_DECRYPT"

  aliases = ["${local.name}-eks"]

  # Grant EKS service access
  key_service_roles_for_autoscaling = [
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  ]

  tags = local.tags
}

module "kms_rds" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 3.0"

  description = "${local.name} Aurora storage encryption key"
  key_usage   = "ENCRYPT_DECRYPT"

  aliases = ["${local.name}-rds"]

  tags = local.tags
}
