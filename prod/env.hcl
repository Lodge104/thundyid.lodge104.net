locals {
  env = "prod"

  # Environment-specific network and workload sizing. Zitadel is a
  # single-instance shared identity service (unlike wp.lodge104.net's
  # per-env WordPress sites), so only "prod" exists -- there is no
  # dev/test environment tree here.
  vpc_cidr = "10.20.0.0/16"

  rds_instances = {
    writer = { instance_class = "db.serverless" }
  }

  rds_scaling = {
    min_capacity = 0
    max_capacity = 4
  }

  zitadel = {
    replica_count    = 2
    admin_username   = "zitadel-admin"
    admin_first_name = "Zitadel"
    admin_last_name  = "Admin"
    admin_email      = "admin@thundyid.lodge104.net"
  }
}
