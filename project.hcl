locals {
  # Project-level constants shared across every environment and region.
  project_name = "net-lodge104-thundyid"
  domain       = "lodge104.net"

  # Zitadel is delegated its own hosted zone ("thundyid.lodge104.net") under
  # the shared lodge104.net root zone, analogous to how wp.lodge104.net
  # delegates "wp.lodge104.net" for WordPress. See global/route53-thundyid
  # and global/route53-parent.
  app_subdomain = "thundyid"
  app_domain    = "thundyid.lodge104.net"
}
