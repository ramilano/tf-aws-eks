locals {
  environment_vars    = read_terragrunt_config("env.hcl")
  region_vars         = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env                 = local.environment_vars.locals.env
  region              = local.region_vars.locals.region
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
}
provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}
EOF
}





remote_state {
  backend = "s3"
  config = {
    bucket         = ""
    key            = "${path_relative_to_include()}/product.tfstate"
    region         = "${local.region}"
    encrypt        = true
    dynamodb_table = ""
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
