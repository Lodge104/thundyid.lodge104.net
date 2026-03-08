# -----------------------------------------------------------------------------
# Route53 DNS Record — thundyid.lodge104.net → ALB
# -----------------------------------------------------------------------------
# Terraform owns this record explicitly. The external-dns annotation has been
# removed from the Zitadel ingress so external-dns does not conflict here.

# Read the ALB hostname from the Zitadel ingress after the Helm release settles.
data "kubernetes_ingress_v1" "zitadel" {
  metadata {
    name      = "zitadel"
    namespace = kubernetes_namespace_v1.zitadel.metadata[0].name
  }

  depends_on = [helm_release.zitadel]
}

# Look up the ALB so we can obtain its hosted-zone ID for an alias record.
data "aws_lb" "zitadel" {
  tags = {
    "ingress.k8s.aws/stack"    = local.name
    "ingress.k8s.aws/resource" = "LoadBalancer"
  }

  depends_on = [helm_release.zitadel]
}

# Alias A-record: thundyid.lodge104.net → ALB
resource "aws_route53_record" "zitadel" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.zitadel.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_lb.zitadel.zone_id
    evaluate_target_health = true
  }
}
