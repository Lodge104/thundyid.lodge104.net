# -----------------------------------------------------------------------------
# Post-provisioning: Create the Zitadel application DB user in Aurora
#
# Aurora's master user (zitadeladmin) is created automatically.  Zitadel
# needs a separate "zitadel" application user for runtime operations.
# This null_resource runs a psql command after Aurora is ready.
# -----------------------------------------------------------------------------

resource "null_resource" "create_zitadel_db_user" {
  triggers = {
    db_endpoint  = module.aurora.cluster_endpoint
    app_password = random_password.zitadel_db_app_password.result
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      PGHOST     = module.aurora.cluster_endpoint
      PGPORT     = "5432"
      PGDATABASE = var.aurora_database_name
      PGUSER     = var.aurora_master_username
      PGPASSWORD = local.aurora_master_password
      PGSSLMODE  = "require"
    }
    command = <<-EOT
      # Wait for database to be reachable
      for i in $(seq 1 30); do
        pg_isready -h "$PGHOST" -p "$PGPORT" && break
        echo "Waiting for database... ($i/30)"
        sleep 10
      done

      # Create the application user and grant permissions
      psql <<SQL
        DO \$\$
        BEGIN
          IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'zitadel') THEN
            CREATE ROLE zitadel LOGIN PASSWORD '${random_password.zitadel_db_app_password.result}';
          ELSE
            ALTER ROLE zitadel PASSWORD '${random_password.zitadel_db_app_password.result}';
          END IF;
        END
        \$\$;

        GRANT ALL PRIVILEGES ON DATABASE ${var.aurora_database_name} TO zitadel;
        ALTER DATABASE ${var.aurora_database_name} OWNER TO zitadel;
      SQL
    EOT
  }

  depends_on = [module.aurora]
}
