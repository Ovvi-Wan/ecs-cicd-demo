variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project_prefix" {
  type    = string
  default = "ecs-cicd-tutorial"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.project_prefix))
    error_message = "Use 3-24 lowercase letters, digits or hyphens, starting with a letter."
  }
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,15}$", var.environment))
    error_message = "Use a short lowercase environment name."
  }
}
variable "vpc_cidr" {
  type        = string
  default     = "10.20.0.0/16"
  description = "An IPv4 /16; the module derives non-overlapping /24 public and private subnets."
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/16$", var.vpc_cidr)) && try(cidrhost(var.vpc_cidr, 0) == split("/", var.vpc_cidr)[0], false)
    error_message = "Supply a network-aligned IPv4 /16, for example 10.20.0.0/16."
  }
}
variable "availability_zones" {
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  description = "Two distinct standard AZs in aws_region. Ordering determines subnet CIDRs; keep it stable. Each AZ has its own NAT gateway."
  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2 && alltrue([for az in var.availability_zones : can(regex("^${var.aws_region}[a-z]$", az))])
    error_message = "Supply two distinct standard AZs in the selected region."
  }
}
