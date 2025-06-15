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

############# EKS #############

variable "eks_version" {
  type = string
}

variable "eks_instance_types" {
  type = list(string)
}

variable "eks_access_entries" {
  type = any
}
