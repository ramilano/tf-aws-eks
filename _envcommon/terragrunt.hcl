terraform {
  source = "../../terraform"
}

locals {
  environment_vars     = read_terragrunt_config("env.hcl")
  region_vars          = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env                  = local.environment_vars.locals.env
  region               = local.region_vars.locals.region
}

inputs = {
  name                     = "product"
  env                      = "${local.env}"
  region                   = "${local.region}"

  tags = {
    env       = "${local.env}"
    name      = "product"
    CreatedBy = "Terraform"
  }

  eks_access_entries = {
    #  admins = {
    #    kubernetes_groups = []
    #    principal_arn     = ""
    #  
    #    policy_associations = {
    #      eks = {
    #        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    #        access_scope = {
    #          namespaces = []
    #          type       = "cluster"
    #        }
    #      }
    #    }
    #  },
    #  devs = {
    #    kubernetes_groups = []
    #    principal_arn     = ""
    #  
    #    policy_associations = {
    #      eks = {
    #        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
    #        access_scope = {
    #          namespaces = ["product"]
    #          type       = "namespace"
    #        }
    #      }
    #    }
    #  }
  }
  features = {
      argocd       = "true"
      monitoring   = "true"
      external_dns = "true"
   }
}
