variable "application" {
  type        = string
  description = "Application name; must match the selected apps directory."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.application)) && var.application != "all"
    error_message = "Use lowercase letters, digits and hyphens; all is reserved."
  }
}

variable "desired_count" {
  type        = number
  description = "Desired task count for the future ECS service; no service exists yet."
  default     = 1
  validation {
    condition     = var.desired_count >= 0 && floor(var.desired_count) == var.desired_count
    error_message = "Desired count must be a nonnegative integer."
  }
}
