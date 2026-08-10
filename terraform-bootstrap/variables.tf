variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "github_owners" {
  description = "GitHub organizations or users allowed to run this repository's CI/CD"
  type        = set(string)
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
}

variable "deploy_managed_policy_arns" {
  description = "Reviewed IAM managed policies for the deployment role; do not use AdministratorAccess"
  type        = set(string)
}

