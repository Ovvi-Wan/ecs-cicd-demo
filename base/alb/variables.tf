variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_prefix" {
  type    = string
  default = "ecs-cicd-tutorial"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_name" {
  description = "Existing VPC Name tag; null uses project_prefix-environment."
  type        = string
  default     = null
}

variable "allowed_http_cidrs" {
  description = "IPv4 clients allowed to reach the public HTTP listener."
  type        = set(string)
  default     = ["0.0.0.0/0"]
  validation {
    condition     = length(var.allowed_http_cidrs) > 0 && alltrue([for cidr in var.allowed_http_cidrs : can(cidrnetmask(cidr))])
    error_message = "Supply at least one valid IPv4 CIDR."
  }
}

variable "target_ports" {
  description = "Task and health-check ports the ALB may reach inside the VPC. Include each app's configured port."
  type        = set(number)
  default     = [3000, 8080]
  validation {
    condition     = length(var.target_ports) > 0 && alltrue([for port in var.target_ports : port >= 1 && port <= 65535 && floor(port) == port])
    error_message = "Supply integer TCP ports from 1 through 65535."
  }
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}
