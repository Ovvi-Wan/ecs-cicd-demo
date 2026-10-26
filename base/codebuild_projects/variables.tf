variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "aws_account_id" {
  type        = string
  description = "Account in which to create the base resources."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Enter your 12-digit AWS account ID."
  }
}
variable "project_prefix" {
  type    = string
  default = "ecs-cicd-tutorial"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.project_prefix))
    error_message = "Use 3-24 lowercase letters, digits or hyphens, starting with a letter."
  }
}
variable "github_connection_arn" {
  type        = string
  description = "ARN of an existing, AVAILABLE GitHub App connection authorized for the configured repositories. Terraform does not manage this connection."
  validation {
    condition     = can(regex("^arn:[a-z0-9-]+:(codeconnections|codestar-connections):[a-z0-9-]+:[0-9]{12}:connection/[A-Za-z0-9-]+$", var.github_connection_arn))
    error_message = "Enter an AWS CodeConnections or legacy CodeStar Connections connection ARN."
  }
}
variable "runner_projects" {
  description = "One repository-scoped runner project per map entry. Keys are stable Terraform resource identities."
  type = map(object({
    repository      = string
    privileged_mode = optional(bool, false)
  }))
  validation {
    condition = length(var.runner_projects) > 0 && alltrue([
      for key, project in var.runner_projects :
      can(regex("^[a-z][a-z0-9-]{0,24}$", key)) &&
      can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$", project.repository))
    ])
    error_message = "Provide at least one project. Keys must be 1-25 lowercase letters/digits/hyphens; repositories must use OWNER/REPO."
  }
}
