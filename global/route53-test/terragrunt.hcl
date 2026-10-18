# Delegated hosted zone for test.thundyid.lodge104.net (analogous to
# wp.lodge104.net/global/route53-test). Test is a full replica of prod's
# architecture but reachable under its own env-prefixed subdomain since it
# runs a separate ALB/cert from prod.
locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53.hcl")
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  app_domain = local.project_vars.locals.app_domain
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Share the prod zone's DNSSEC KMS key instead of letting this zone create
# its own (module default create_dnssec_kms_key = true) -- DNSSEC signing
# keys are cheap to share across zones (one ECC_NIST_P256 key is ~$1/mo)
# since each zone still gets its own Key Signing Key resource, just backed
# by the same KMS key. 3 zones x 1 key each -> 1 key total.
#
# IMPORTANT -- do not apply this zone-key change blind against a live
# zone. Switching key_management_service_arn on an existing
# aws_route53_key_signing_key forces replacement, which AWS's API only
# allows while DNSSEC signing is disabled. Roll out as:
#   1. Remove this zone's DS record from
#      global/route53-env-delegation and apply it; wait out the record's
#      TTL (300s).
#   2. Temporarily set enable_dnssec = false here and apply (deletes the
#      old KSK + its dedicated KMS key).
#   3. Set it back to true (as below, now pointing at the shared key) and
#      apply (creates a new KSK against the shared key).
#   4. Re-add this zone's DS record in route53-env-delegation and apply.
dependency "thundyid_zone" {
  config_path = "../route53-thundyid"

  mock_outputs = {
    dnssec_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    create_zone           = true
    name                  = "test.${local.app_domain}"
    enable_dnssec         = true
    create_dnssec_kms_key = false
    dnssec_kms_key_arn    = dependency.thundyid_zone.outputs.dnssec_kms_key_arn
    records               = {}
  }
)
