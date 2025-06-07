# AWS EKS Infrastructure with Terragrunt

This repository contains Terraform/Terragrunt infrastructure-as-code for deploying a production-ready AWS EKS cluster with optional GitOps, monitoring, and DNS management features.

## Basic Usage

The basic deployment creates:
- **EKS Cluster** with AWS managed node groups
- **Karpenter** control plane pool for autoscaling
- **Dual-architecture support**: ARM64 and AMD64 node pools with spot instances
- **AWS Load Balancer Controller** for ingress management
- **Secrets Store CSI Driver** for AWS secrets integration

### Quick Start

1. **Configure AWS credentials**:
   ```bash
   # Update vars.sh with your AWS credentials
   source vars.sh
   ```

2. **Initialize AWS resources**:
   ```bash
   ./init.sh
   ```
   This creates the S3 bucket and DynamoDB table for Terraform state management.

3. **Deploy the cluster**:
   ```bash
   cd eu-west-1/prod
   terragrunt init
   terragrunt plan
   terragrunt apply
   ```

## Optional Features

Enable additional features by setting the `features` map in your environment configuration:

### ArgoCD GitOps (argocd = "true")

When enabled, deploys:
- **ArgoCD** server in the `argocd` namespace
- **Root Application** from [ramilano/argocd-root-app](https://github.com/ramilano/argocd-root-app.git)
- **Demo Application** deployment from [ramilano/demo-app](https://github.com/ramilano/demo-app.git) using the Helm chart [ramilano/helm-demo-app](https://github.com/ramilano/helm-demo-app.git)

The ArgoCD application automatically manages the demo application deployment through GitOps workflow.
Demo application have gitflow based github workflow to build push and update helm chart version.

### External DNS (external_dns = "true")

When enabled, deploys:
- **External DNS controller** for public zones only
- **Automatic DNS record management** for services with ALB ingresses
- **Certificate management** for public domains

**Required variables**:
- `domain`: Public domain for external services

Terraform automatically handles:
- SSL certificate creation for public domain
- Route53 public zone management
- ALB integration with automatic DNS updates

### Monitoring Stack (monitoring = "true")

When enabled, deploys a complete observability stack:
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation and querying
- **Tempo**: Distributed tracing
- **Promtail**: Log shipping to Loki
- **OpenTelemetry Collector**: Telemetry data collection
- **AlertManager**: Alert routing and notification

The monitoring stack includes:
- Pre-configured dashboards
- Slack integration for alerts
- S3 storage for long-term data retention
- Automatic ingress with SSL certificates

## Configuration

### Environment Structure

```
eu-west-1/prod/
env.hcl          # Environment-specific settings
terragrunt.hcl   # Main configuration with feature flags
```

### Feature Configuration Example

```hcl
# In eu-west-1/prod/terragrunt.hcl
inputs = {
  features = {
    argocd       = "true"   # Enable GitOps
    monitoring   = "true"   # Enable observability stack
    external_dns = "true"   # Enable DNS automation
  }
  
  # Required for external_dns
  domain         = "example.com"
  
  # Required for monitoring alerts
  slack_token   = "xoxb-your-slack-token"
  slack_channel = "#alerts"
  slack_url     = "https://hooks.slack.com/your-webhook"
  
  # Required for ArgoCD Git integration
  git_username = "your-github-username"
  git_password = "your-github-token"
}
```

## Architecture

![EKS Infrastructure Architecture](diagram.png)

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


### Networking
- Multi-AZ VPC with public, private, database, and intra subnets
- NAT Gateway for private subnet internet access
- Security groups optimized for EKS

### Storage
- GP3 default storage class with XFS filesystem
- EBS CSI driver for persistent volumes
- S3 buckets for monitoring data retention

## Accessing Services

After deployment with features enabled:

### ArgoCD
- URL: `https://argo.{domain}`
- Login with admin credentials stored in Kubernetes secrets

### Grafana
- URL: `https://grafana.{domain}`
- Auto-generated admin password available in Terraform outputs

### Prometheus
- URL: `https://prom.{domain}`

## State Management

- **Remote State**: S3 bucket with versioning and encryption
- **State Locking**: DynamoDB table prevents concurrent modifications
- **State Key**: `{path_relative_to_include()}/product.tfstate`

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Terragrunt >= 0.45
- kubectl for cluster access
- helm for chart management

## Clean Up

```bash
cd eu-west-1/prod
terragrunt destroy
```

**Note**: S3 buckets and DynamoDB table for state management are not destroyed automatically.