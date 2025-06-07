module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"
  
  count        = var.features["external_dns"] == "true" ? 1 : 0
  domain_name  = data.aws_route53_zone.zone[0].name
  zone_id      = data.aws_route53_zone.zone[0].zone_id

  validation_method = "DNS"

  subject_alternative_names = [
    "${data.aws_route53_zone.zone[0].name}",
    "*.${data.aws_route53_zone.zone[0].name}"
  ]

  create_route53_records  = true

  wait_for_validation = true

  tags = var.tags
}





