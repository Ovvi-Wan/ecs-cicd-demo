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
