# AWS EKS Infrastructure with terraform

This repository contains Terraform/Terragrunt infrastructure-as-code for deploying AWS EKS cluster.

## Basic Usage

The basic deployment creates:
- **EKS Cluster** with AWS managed node groups
- **Karpenter** control plane pool for autoscaling
- **Dual-architecture support**: ARM64 and AMD64 node pools with spot instances

### Quick Start
```bash
terraform init
terraform plan
terraform apply
```

### Node Pools
- **Control Plane Pool**: ARM64 instances with Karpenter management
- **ARM64 Node Pool**: Spot instances (t4g, m6g, c6g families)
- **AMD64 Node Pool**: Spot instances (t3, t3a, m5, m5a, c5, c5a families)

Demo application helm chart already has affinity to schedule on arm64/amd64 nodes

```
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/arch
          operator: In
          values:
          - amd64
          #- arm64
```
