resource "helm_release" "secrets_csi" {
  depends_on = [module.eks]
  name       = "csi-secrets-store"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.5.1"
}


resource "helm_release" "csi_provider_aws" {
  depends_on = [module.eks, helm_release.secrets_csi]
  name       = "secrets-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.11"

  values = [file("${path.module}/helm_values/secrets-provider-aws.yml")]
}

resource "helm_release" "aws_load_balancer_controller" {
  depends_on = [module.eks]
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  values     = [file("${path.module}/helm_values/alb-controller.yml")]
  version    = "1.13.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
}

resource "helm_release" "argo_cd" {
  depends_on       = [module.eks]
  count            = var.features["argocd"] == "true" ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  create_namespace = true
  namespace        = "argocd"
  version          = "8.0.14"
  force_update     = true

  values = [templatefile("${path.module}/helm_values/argocd.yml", {
    env             = var.env
    name            = var.name
    slack_token     = var.slack_token
    slack_channel   = var.slack_channel
    hostname        = "argo.${var.domain}"
    git_username    = var.git_username
    git_password    = var.git_password
    certificate_arn = module.acm[0].acm_certificate_arn
  })]
}

resource "helm_release" "external_dns_public" {
  depends_on = [module.eks]
  count      = var.features["external_dns"] == "true" ? 1 : 0
  name       = "external-dns-public"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.16.1"

  values = [templatefile("${path.module}/helm_values/external-dns-public.yml", {
    domain = var.domain
    aws_region = var.region
  })]
}

resource "helm_release" "prometheus_stack" {
  depends_on       = [module.eks]
  count            = var.features["monitoring"] == "true" ? 1 : 0
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "72.9.0"
  namespace        = "monitoring"
  create_namespace = true

  values = [templatefile("${path.module}/helm_values/kube-prometheus-stack.yml", {
    grafana_admin_password = "${random_password.grafana_psw[0].result}"
    env                    = var.env
    name                   = var.name
    slack_api_url          = var.slack_url
    slack_channel          = var.slack_channel
    grafana_hostname       = "grafana.${var.domain}"
    prometheus_hostname    = "prom.${var.domain}"
    alertmanager_hostname  = "alert.${var.domain}"
    certificate_arn        = module.acm[0].acm_certificate_arn
  })]
}

resource "helm_release" "loki" {
  depends_on = [module.eks, module.loki_chunks_bucket, module.loki_ruler_bucket, helm_release.prometheus_stack]
  count      = var.features["monitoring"] == "true" ? 1 : 0
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "6.30.1"
  namespace  = "monitoring"

  values = [templatefile("${path.module}/helm_values/loki.yml", {
    chunks_bucket = "${var.name}-${var.env}-${var.region}-loki-chunks"
    ruler_bucket  = "${var.name}-${var.env}-${var.region}-loki-ruler"
    region        = var.region
  })]
  wait = false
}

resource "helm_release" "promtail" {
  depends_on = [module.eks, helm_release.loki]
  count      = var.features["monitoring"] == "true" ? 1 : 0
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.17.0"
  namespace  = "monitoring"
  create_namespace = false
  values = [file("${path.module}/helm_values/promtail.yml")]
}


resource "helm_release" "tempo" {
  depends_on = [module.eks, module.tempo_s3_bucket, helm_release.prometheus_stack]
  count      = var.features["monitoring"] == "true" ? 1 : 0
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo-distributed"
  version    = "1.40.4"
  namespace  = "monitoring"
  values = [templatefile("${path.module}/helm_values/tempo.yml", {
    region = var.region
    bucket = "${var.name}-${var.env}-${var.region}-tempo-data"
    role_arn   = module.tempo_irsa_role[0].iam_role_arn
  })]
}


resource "helm_release" "otel" {
  depends_on = [module.eks]
  count      = var.features["monitoring"] == "true" ? 1 : 0
  name       = "otel"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = "0.126.0"
  namespace  = "monitoring"

  values = [file("${path.module}/helm_values/otel.yml")]
  set {
    name  = "image.repository"
    value = "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s"
  }
  set {
    name  = "command.name"
    value = "otelcol-k8s"
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"
  namespace  = "kube-system"
  values     = [file("${path.module}/helm_values/metrics-server.yml")]
}

