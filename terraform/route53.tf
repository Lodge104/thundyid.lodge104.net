# -----------------------------------------------------------------------------
# Route53 DNS Record — thundyid.lodge104.net → ALB
# -----------------------------------------------------------------------------
# Uses a CNAME so we don't need to look up the ALB zone ID at plan time.
# The ALB hostname is read from the Kubernetes Ingress status after Helm deploys.

data "kubernetes_ingress_v1" "zitadel" {
  metadata {
    name      = "zitadel"
    namespace = kubernetes_namespace_v1.zitadel.metadata[0].name
  }

  depends_on = [helm_release.zitadel]
}

resource "aws_route53_record" "zitadel" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = 60
  records = [data.kubernetes_ingress_v1.zitadel.status[0].load_balancer[0].ingress[0].hostname]
}
