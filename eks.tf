module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "${var.name}-${var.env}-eks"
  cluster_version = var.eks_version

  cluster_endpoint_public_access  = true
  create_cloudwatch_log_group     = false
  cluster_enabled_log_types       = []

  cluster_encryption_config = {}


  cluster_addons = {
    coredns = {
      before_compute = true
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }

    kube-proxy = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_groups = {
    karpenter = {
      instance_types             = var.eks_instance_types
      ami_type                   = "AL2_ARM_64"
      iam_role_attach_cni_policy = false
      enable_monitoring          = false
      iam_role_use_name_prefix   = false
      iam_role_name              = "${local.name}-${var.region}-karpenter-ng-role"
      
      attach_cluster_primary_security_group = false

      min_size     = 3
      max_size     = 5
      desired_size = 3
      

      labels = {
        # Used to ensure Karpenter runs on nodes that it does not manage
        "karpenter.sh/controller" = "true"
      }

      taints = {
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  enable_cluster_creator_admin_permissions = true
  enable_irsa = true

  access_entries = var.eks_access_entries

  create_node_security_group = false

  tags = merge(var.tags, {
    "karpenter.sh/discovery" = "${var.name}-${var.env}-eks"
  })
}


module "karpenter" {
  create = true
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  create_iam_role          = true
  iam_role_use_name_prefix = false
  iam_role_name            = "${local.name}-${var.region}-karpenter-controller-role"
  cluster_name             = module.eks.cluster_name

  enable_pod_identity             = true
  create_pod_identity_association = true

  create_node_iam_role    = false
  enable_spot_termination = true
  node_iam_role_arn       = module.eks.eks_managed_node_groups["karpenter"].iam_role_arn

  # Since the nodegroup role will already have an access entry
  create_access_entry = false

  tags = var.tags
}

resource "helm_release" "karpenter_crd" {
  namespace           = "kube-system"
  name                = "karpenter-crd"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  repository          = "oci://public.ecr.aws/karpenter"
  version             = "1.4.0"
  chart               = "karpenter-crd"
}


resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.4.0"
  wait                = false

  values = [
    <<-EOT
    serviceAccount:
      name: ${module.karpenter.service_account}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
    replicas: 1
    EOT
  ]
  depends_on = [ helm_release.karpenter_crd ]

}

# ARM64 Node Class
resource "kubectl_manifest" "karpenter_node_class_arm64" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: arm64-nodeclass
    spec:
      kubelet:
        maxPods: 110
      amiFamily: AL2
      role: "${module.eks.eks_managed_node_groups["karpenter"].iam_role_name}"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      amiSelectorTerms:
        - id: ami-02b9e7fb38d48ad8c
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

# AMD64 Node Class
resource "kubectl_manifest" "karpenter_node_class_amd64" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: amd64-nodeclass
    spec:
      kubelet:
        maxPods: 110
      amiFamily: AL2
      role: "${module.eks.eks_managed_node_groups["karpenter"].iam_role_name}"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      amiSelectorTerms:
        - id: ami-04f8ef14ad4e6b1f9
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

# ARM64 Node Pool
resource "kubectl_manifest" "karpenter_node_pool_arm64" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: arm64-nodepool
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: arm64-nodeclass
          requirements:
            - key: topology.kubernetes.io/zone
              operator: In
              values: ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["t"]
            - key: "karpenter.k8s.aws/instance-family"
              operator: In
              values: ["t4g"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["arm64"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]
          nodeLabels:
            node.kubernetes.io/architecture: "arm64"
            karpenter.sh/provisioner-name: "arm64-nodepool"
      limits:
        cpu: 32
        memory: 64Gi
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class_arm64
  ]
}

# AMD64 Node Pool
resource "kubectl_manifest" "karpenter_node_pool_amd64" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: amd64-nodepool
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: amd64-nodeclass
          requirements:
            - key: topology.kubernetes.io/zone
              operator: In
              values: ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["t"]
            - key: "karpenter.k8s.aws/instance-family"
              operator: In
              values: ["t3", "t3a"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]
          nodeLabels:
            node.kubernetes.io/architecture: "amd64"
            karpenter.sh/provisioner-name: "amd64-nodepool"
      limits:
        cpu: 32
        memory: 64Gi
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class_amd64
  ]
}