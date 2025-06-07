# Public External DNS Pod Identity
module "external_dns_pod_identity_public" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  
  count = var.features["external_dns"] == "true" ? 1 : 0

  name = "${local.name}-${var.region}-ext-dns-pub-pi-role"
  use_name_prefix = false

  attach_external_dns_policy    = true
  external_dns_policy_name     = "${local.name}-${var.region}-ext-dns-pub-policy"
  external_dns_hosted_zone_arns = [
    data.aws_route53_zone.zone[0].arn
  ]

  association_defaults = {
    namespace       = "kube-system"
    service_account = "external-dns-public"
  }

  associations = {
    eks = {
      cluster_name = module.eks.cluster_name
    }
  }

  tags = var.tags
}

module "aws_ebs_csi_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "${local.name}-${var.region}-ebs-csi-pi-role"
  use_name_prefix = false

  attach_aws_ebs_csi_policy = true
  aws_ebs_csi_policy_name  = "${local.name}-${var.region}-ebs-csi-policy"

  association_defaults = {
    namespace       = "kube-system"
    service_account = "ebs-csi-controller-sa"
  }

  associations = {
    eks = {
      cluster_name = module.eks.cluster_name
    }
  }

  tags = var.tags
}

module "aws_lb_controller_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "${local.name}-${var.region}-lbc-pi-role"
  use_name_prefix = false

  attach_aws_lb_controller_policy = true
  aws_lb_controller_policy_name  = "${local.name}-${var.region}-lbc-policy"

  association_defaults = {
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller"
  }

  associations = {
    eks = {
      cluster_name = module.eks.cluster_name
    }
  }

  tags = var.tags
}

module "aws_vpc_cni_ipv4_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "${local.name}-${var.region}-cni-pi-role"
  use_name_prefix = false

  attach_aws_vpc_cni_policy = true
  aws_vpc_cni_enable_ipv4   = true
  aws_vpc_cni_policy_name   = "${local.name}-${var.region}-cni-policy"

  association_defaults = {
    namespace       = "kube-system"
    service_account = "aws-node"
  }

  associations = {
    eks = {
      cluster_name = module.eks.cluster_name
    }
  }

  tags = var.tags
}




# Loki Pod Identity
module "loki_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  
  count = var.features["monitoring"] == "true" ? 1 : 0

  name = "${local.name}-${var.region}-loki-pi-role"
  use_name_prefix = false

  attach_custom_policy = true

  policy_statements = [
    {
      sid = "ListAllinChunksBucket"
      effect = "Allow"
      actions = ["s3:ListBucket", "s3:ListObjectsV2"]
      resources = ["arn:aws:s3:::${local.name}-${var.region}-loki-chunks"]
    },
    {
      sid = "AllObjectActionsChunksBucket"
      effect = "Allow"
      actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectAcl", "s3:GetObjectAcl"]
      resources = ["arn:aws:s3:::${local.name}-${var.region}-loki-chunks/*"]
    },
    {
      sid = "ListAllinRulerBucket"
      effect = "Allow"
      actions = ["s3:ListBucket", "s3:ListObjectsV2"]
      resources = ["arn:aws:s3:::${local.name}-${var.region}-loki-ruler"]
    },
    {
      sid = "AllObjectActionsRulerBucket"
      effect = "Allow"
      actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectAcl", "s3:GetObjectAcl"]
      resources = ["arn:aws:s3:::${local.name}-${var.region}-loki-ruler/*"]
    }
  ]

  association_defaults = {
    namespace       = "monitoring"
    service_account = "loki"
  }

  associations = {
    eks = {
      cluster_name = module.eks.cluster_name
    }
  }
  tags = var.tags
}

data "aws_iam_policy_document" "tempo" {
  count = var.features["monitoring"] == "true" ? 1 : 0
  statement {
    sid = "ListAllinBucket"
    effect = "Allow"
    actions = ["s3:ListBucket", "s3:ListObjectsV2", "s3:ListObjects"]
    resources = ["arn:aws:s3:::${local.name}-${var.region}-tempo-data"]
  }
  statement {
    sid = "AllObjectActions"
    effect = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectAcl", "s3:GetObjectAcl", "s3:GetObjectTagging", "s3:PutObjectTagging"]
    resources = ["arn:aws:s3:::${local.name}-${var.region}-tempo-data/*"]
  }
}


resource "aws_iam_policy" "tempo" {
  count = var.features["monitoring"] == "true" ? 1 : 0
  name = "${local.name}-${var.region}-tempo-policy"
  policy = data.aws_iam_policy_document.tempo[0].json
}



module "tempo_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  
  count = var.features["monitoring"] == "true" ? 1 : 0

  role_name              = "${local.name}-${var.region}-tempo-irsa-role"
  allow_self_assume_role = true

  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["monitoring:tempo"]
    }
  }

  role_policy_arns = {
    additional = aws_iam_policy.tempo[0].arn
  }
}
