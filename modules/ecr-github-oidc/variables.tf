variable "ecr_repositories" {
  type        = set(string)
  description = "Set of ECR repository names to create"
}

variable "github_repositories" {
  type        = list(string)
  description = "List of GitHub repository subjects for OIDC (format: repo:owner/repo:ref:refs/heads/main)"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}