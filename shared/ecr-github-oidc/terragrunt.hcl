include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../modules/ecr-github-oidc"
}

inputs = {
  ecr_repositories = [
    "demo-app"
  ]
  
  github_repositories = [
    "repo:ramilano/demo-app:ref:refs/heads/main",
    "repo:ramilano/demo-app:ref:refs/heads/develop", 
    "repo:ramilano/demo-app:ref:refs/heads/release/*",
    "repo:ramilano/demo-app:ref:refs/heads/hotfix/*"
  ]

  tags = {
    Environment = "shared"
    Project     = "demo"
    ManagedBy   = "terragrunt"
  }
}