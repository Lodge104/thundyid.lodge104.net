locals {
  env = "test"

  # Environment-specific network and workload sizing. dev/test/prod are
  # exact replicas of each other (same sizing/architecture); only the env
  # name and the resulting domain/zone differ.
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
