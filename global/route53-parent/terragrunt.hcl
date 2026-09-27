# Delegates the "thundyid" subdomain from the shared lodge104.net root zone
# to the zone created in ../route53-thundyid, mirroring how
# wp.lodge104.net/global/route53-parent delegates "wp".
locals {
  common       = read_terragrunt_config("${get_repo_root()}/_common/route53.hcl")
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl"))

  domain        = local.project_vars.locals.domain
  app_subdomain = local.project_vars.locals.app_subdomain
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "thundyid_zone" {
  config_path = "../route53-thundyid"

  mock_outputs = {
    name_servers = [
      "ns-123.awsdns-01.net",
      "ns-456.awsdns-02.org",
      "ns-789.awsdns-03.co.uk",
      "ns-012.awsdns-04.com",
    ]
    dnssec_signing_key_ds_record = "12345 13 2 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "apply", "destroy"]
}

terraform {
  source = "tfr:///terraform-aws-modules/route53/aws?version=6.5.0"
}

inputs = merge(
  local.common.locals,
  {
    name = local.domain
    records = {
      thundyid_delegation = {
        name    = local.app_subdomain
        type    = "NS"
        ttl     = 300
        records = dependency.thundyid_zone.outputs.name_servers
      }
      thundyid_ds = {
        name    = local.app_subdomain
        type    = "DS"
        ttl     = 300
        records = compact([try(dependency.thundyid_zone.outputs.dnssec_signing_key_ds_record, null)])
      }
    }
  }
)
