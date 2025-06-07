############### General ###############

variable "tags" {
  type = map(string)
}

variable "env" {
  type = string
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

############### Networking ###############

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type = bool
}

variable "single_nat_gateway" {
  type = bool
}

variable "one_nat_gateway_per_az" {
  type = bool
}

variable "enable_vpn_gateway" {
  type = bool
}

variable "database_subnet_cidrs" {
  type = list(string)
}

variable "intra_subnet_cidrs" {
  type = list(string)
}

############# EKS #############

variable "namespaces" {
  type = map(string)
}

variable "eks_version" {
  type = string
}

variable "eks_instance_types" {
  type = list(string)
}


variable "eks_access_entries" {
  type = any
}

############## GitOps ##############
variable "git_password" {
  type = string
  description = "Access token for git operations"
}

variable "git_username" {
  type = string
  description = "Username for git operations"
  
}

variable "slack_token" {
  type = string
  description = "Slack token for notifications"
  
}

variable "slack_channel" {
  type = string
  description = "Slack channel for notifications"
}

variable "slack_url" {
  type = string
  description = "Slack webhook URL for notifications"
  
}

variable "domain" {
  type = string
  description = "Domain for the application"
  
}

variable "features" {
  type = map(string)
  description = "Features to enable in the EKS cluster, e.g., argocd, monitoring, external_dns"
}

