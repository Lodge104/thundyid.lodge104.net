# Delegates the "dev" and "test" subdomains from the thundyid.lodge104.net
# zone (created in ../route53-thundyid) down to their own per-env zones
# (../route53-dev, ../route53-test), mirroring
# wp.lodge104.net/global/route53-env-delegation.
locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53.hcl")
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  app_domain = local.project_vars.locals.app_domain
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "dev_zone" {
  config_path = "../route53-dev"

  mock_outputs = {
    name_servers = [
      "ns-111.awsdns-01.net",
      "ns-222.awsdns-02.org",
      "ns-333.awsdns-03.co.uk",
      "ns-444.awsdns-04.com",
    ]
    dnssec_signing_key_ds_record = "12345 13 2 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

dependency "test_zone" {
  config_path = "../route53-test"

  mock_outputs = {
    name_servers = [
      "ns-555.awsdns-01.net",
      "ns-666.awsdns-02.org",
      "ns-777.awsdns-03.co.uk",
      "ns-888.awsdns-04.com",
    ]
    dnssec_signing_key_ds_record = "12345 13 2 BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    name = local.app_domain
    records = {
      dev_delegation = {
        name    = "dev"
        type    = "NS"
        ttl     = 300
        records = dependency.dev_zone.outputs.name_servers
      }
      dev_ds = {
        name    = "dev"
        type    = "DS"
        ttl     = 300
        records = compact([try(dependency.dev_zone.outputs.dnssec_signing_key_ds_record, null)])
      }
      test_delegation = {
        name    = "test"
        type    = "NS"
        ttl     = 300
        records = dependency.test_zone.outputs.name_servers
      }
      test_ds = {
        name    = "test"
        type    = "DS"
        ttl     = 300
        records = compact([try(dependency.test_zone.outputs.dnssec_signing_key_ds_record, null)])
      }
    }
  }
)
