variable "cluster_name" {
  type        = string
  description = "Name of the existing shared ECS cluster."
}
variable "network" {
  type = object({
    vpc_id   = optional(string)
    vpc_name = optional(string)
  })
  validation {
    condition     = (var.network.vpc_id != null) != (var.network.vpc_name != null)
    error_message = "Specify exactly one VPC ID or Name tag."
  }
}
variable "load_balancer" {
  type = object({
    existing_name = optional(string)
    listener_port = optional(number, 80)
  })
  default = {}
  validation {
    condition     = !var.lb_enabled || var.load_balancer.existing_name != null
    error_message = "When lb_enabled=true, specify the existing ALB name."
  }
}

variable "lb_enabled" {
  type        = bool
  default     = false
  description = "Attach the application to an existing ALB when true. No ALB is created."
}
