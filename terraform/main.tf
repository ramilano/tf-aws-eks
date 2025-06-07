resource "random_password" "grafana_psw" {
  count   = var.features["monitoring"] == "true" ? 1 : 0
  length  = 16
  special = true
}

resource "kubernetes_namespace" "ns" {
  for_each = var.namespaces
  metadata {
    name = each.value
  }
  depends_on = [
    module.eks
  ]
}

resource "kubernetes_storage_class" "sc" {
  metadata {
    name = "gp3"
     annotations = {
      "storageclass.kubernetes.io/is-default-class" = true
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    "csi.storage.k8s.io/fstype" = "xfs"
    type = "gp3"
  }

  allowed_topologies {
    match_label_expressions {
      key      = "topology.kubernetes.io/zone"
      values   = data.aws_availability_zones.azs.names
    }
  }
  depends_on = [
    module.eks
  ]
}


resource "kubectl_manifest" "argocd_app" {
  count     = var.features["argocd"] == "true" ? 1 : 0
  yaml_body = templatefile("${path.module}/templates/app.tpl", {
    path          = "."
    namespace     = "product"
    url           = "https://github.com/ramilano/argocd-root-app.git"
    name          = "demo"
    ishelm        = "true"
  })

  depends_on = [ 
    module.eks,
    helm_release.argo_cd
  ]
}
