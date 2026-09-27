# Common ACM defaults – override in each env's terragrunt.hcl as needed.
locals {
  validation_method   = "DNS"
  wait_for_validation = true
}
