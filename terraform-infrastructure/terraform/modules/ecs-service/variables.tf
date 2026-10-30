variable "name" { type = string }
variable "cluster_arn" { type = string }
variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = set(string) }
variable "network" { type = any }
variable "port" { type = number }
variable "container_name" { type = string }
variable "task" {
  type = object({
    cpu                   = optional(number, 256)
    memory                = optional(number, 512)
    architecture          = optional(string, "X86_64")
    ephemeral_storage_gib = optional(number)

  })
  default = {}
  validation {
    condition     = contains(["X86_64", "ARM64"], var.task.architecture) && contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.task.cpu)
    error_message = "Select a supported Linux Fargate CPU size and X86_64 or ARM64."
  }
  validation {
    condition = contains(lookup({
      "256"   = [512, 1024, 2048]
      "512"   = [1024, 2048, 3072, 4096]
      "1024"  = range(2048, 8193, 1024)
      "2048"  = range(4096, 16385, 1024)
      "4096"  = range(8192, 30721, 1024)
      "8192"  = range(16384, 61441, 4096)
      "16384" = range(32768, 122881, 8192)
    }, tostring(var.task.cpu), []), var.task.memory)
    error_message = "Unsupported Fargate CPU/memory combination; memory is in MiB."
  }
  validation {
    condition     = (var.task.ephemeral_storage_gib == null ? true : (var.task.ephemeral_storage_gib >= 21 && var.task.ephemeral_storage_gib <= 200 && floor(var.task.ephemeral_storage_gib) == var.task.ephemeral_storage_gib))
    error_message = "Omit storage for the included 20 GiB, or set an integer from 21-200 GiB."
  }

}
variable "execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "region" { type = string }
variable "desired_count" { type = number }
variable "config" { type = any }
variable "scaling" { type = any }
variable "lb_enabled" { type = bool }
variable "alb_security_group_id" { type = string }

variable "logging" {
  type = object({
    retention_in_days = optional(number, 14)
    kms_key_arn       = optional(string)
    skip_destroy      = optional(bool, false)
  })
  default = {}
}
variable "secret" {
  type = object({
    create                  = optional(bool, true)
    description             = optional(string, "Application configuration; populate securely before deployment")
    recovery_window_in_days = optional(number, 30)
  })
  default = {}

}
variable "secret_name" { type = string }

variable "alb_listener_arn" { type = string }
variable "load_balancer" {
  type = object({
    deregistration_delay = optional(number, 30)
    slow_start           = optional(number, 0)
    rules = optional(map(object({
      priority      = number
      path_patterns = optional(list(string), [])
      host_headers  = optional(list(string), [])
    })), {})
  })
  default = {}
}
variable "health_check" {
  type = object({
    path                = optional(string, "/health")
    port                = optional(string, "traffic-port")
    matcher             = optional(string, "200")
    interval            = optional(number, 30)
    timeout             = optional(number, 5)
    healthy_threshold   = optional(number, 2)
    unhealthy_threshold = optional(number, 3)
  })
  default = {}
}
