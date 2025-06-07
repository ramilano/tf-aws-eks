data "aws_availability_zones" "azs" {
  state = "available"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "zone" {
  count = var.features["external_dns"] == "true" ? 1 : 0
  name  = var.domain
}
