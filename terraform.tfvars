name = "product"
region = ""
env = ""
tags = {
  env       = ""
  name      = "product"
  CreatedBy = "Terraform"
}
eks_access_entries = {}

vpc_cidr               = "10.0.0.0/16"
private_subnet_cidrs   = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
public_subnet_cidrs    = ["10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19"]
eks_version = "1.32"
enable_vpn_gateway    = false
enable_nat_gateway     = true
single_nat_gateway     = true
one_nat_gateway_per_az = false
eks_instance_types = ["t4g.medium"]