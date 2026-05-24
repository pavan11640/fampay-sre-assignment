variable "project_name" {
  description = "Project name prefix for repositories"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "repository_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = ["hodr", "bran"]
}
