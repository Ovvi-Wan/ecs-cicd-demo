variable "application" {
  type        = string
  description = "App directory name. app-example is documentation only and cannot deploy."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,29}$", var.application)) && !contains(["all", "app-example"], var.application)
    error_message = "Use 1-30 lowercase letters/digits/hyphens; all and app-example are reserved."
  }
  validation {
    condition     = length("${var.project_prefix}-${var.environment}-${var.application}") <= 46
    error_message = "Keep project_prefix-environment-application at most 46 characters so AWS resource names fit."
  }
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project_prefix" {
  type    = string
  default = "ecs-cicd-tutorial"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.project_prefix))
    error_message = "Prefix must be 3-24 lowercase letters/digits/hyphens."
  }
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,14}$", var.environment))
    error_message = "Environment must be 1-15 lowercase letters/digits/hyphens."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "cluster_name" {
  type        = string
  description = "Existing shared cluster; create separately in base/ecs_cluster if needed."
}
variable "network" {
  description = "Supply vpc_id OR vpc_name. Subnets are discovered within that VPC using Tier=private."
  type = object({
    vpc_id                             = optional(string)
    vpc_name                           = optional(string)
    additional_task_security_group_ids = optional(set(string), [])
    task_ingress = optional(map(object({
      port                     = number
      cidr_ipv4                = optional(string)
      source_security_group_id = optional(string)
      description              = optional(string, "Application ingress")
    })), {})
    task_egress = optional(map(object({
      protocol                      = optional(string, "-1")
      from_port                     = optional(number)
      to_port                       = optional(number)
      cidr_ipv4                     = optional(string)
      destination_security_group_id = optional(string)
      description                   = optional(string, "Application egress")
    })), { all = { cidr_ipv4 = "0.0.0.0/0" } })
  })
  validation {
    condition     = (var.network.vpc_id != null) != (var.network.vpc_name != null)
    error_message = "Specify exactly one of network.vpc_id and network.vpc_name."
  }
  validation {
    condition     = alltrue([for r in values(var.network.task_ingress) : (r.cidr_ipv4 != null) != (r.source_security_group_id != null)]) && alltrue([for r in values(var.network.task_egress) : (r.cidr_ipv4 != null) != (r.destination_security_group_id != null)])
    error_message = "Each security-group rule requires exactly one CIDR or security-group source/destination."
  }
}
variable "container_port" {
  type    = number
  default = 8080
  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535 && floor(var.container_port) == var.container_port
    error_message = "container_port must be an integer from 1 through 65535."
  }
}
variable "container_name" {
  type    = string
  default = "app"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.container_name))
    error_message = "Container name must contain only letters, digits, underscores or hyphens."
  }
}
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
variable "desired_count" {
  type    = number
  default = 1
  validation {
    condition     = var.desired_count >= 0 && floor(var.desired_count) == var.desired_count
    error_message = "Desired count must be a nonnegative integer."
  }
}
variable "service" {
  type = object({
    platform_version                  = optional(string, "1.4.0")
    minimum_healthy_percent           = optional(number, 100)
    maximum_percent                   = optional(number, 200)
    health_check_grace_period_seconds = optional(number, 60)
    rollback                          = optional(bool, true)
    wait_for_steady_state             = optional(bool, true)
  })
  default = {}
  validation {
    condition     = var.service.minimum_healthy_percent >= 0 && var.service.minimum_healthy_percent <= 100 && var.service.maximum_percent > 100 && var.service.maximum_percent <= 200
    error_message = "Minimum healthy must be 0-100; maximum must be greater than 100 and at most 200."
  }
  validation {
    condition     = contains(["1.4.0", "LATEST"], var.service.platform_version)
    error_message = "Use Linux Fargate 1.4.0 or LATEST for the supported storage/runtime settings."
  }
}
variable "load_balancer" {
  type = object({
    existing_name        = optional(string)
    listener_port        = optional(number, 80)
    deregistration_delay = optional(number, 30)
    slow_start           = optional(number, 0)
    rules = optional(map(object({
      priority      = number
      path_patterns = optional(list(string), [])
      host_headers  = optional(list(string), [])
    })), {})
  })
  default = {}
  validation {
    condition     = !var.lb_enabled || (var.load_balancer.existing_name != null && length(var.load_balancer.rules) > 0)
    error_message = "When lb_enabled=true, specify existing_name and at least one routing rule."
  }
  validation {
    condition     = alltrue([for r in values(var.load_balancer.rules) : r.priority >= 1 && r.priority <= 50000 && floor(r.priority) == r.priority && length(r.path_patterns) + length(r.host_headers) > 0 && length(r.path_patterns) + length(r.host_headers) <= 5]) && length(distinct([for r in values(var.load_balancer.rules) : r.priority])) == length(var.load_balancer.rules)
    error_message = "Rules need unique integer priorities 1-50000 and 1-5 host/path values."
  }
  validation {
    condition     = var.load_balancer.listener_port >= 1 && var.load_balancer.listener_port <= 65535 && floor(var.load_balancer.listener_port) == var.load_balancer.listener_port
    error_message = "Listener port must be 1-65535."
  }
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
  validation {
    condition     = startswith(var.health_check.path, "/") && var.health_check.timeout < var.health_check.interval
    error_message = "Health path must start with / and timeout must be below interval."
  }
  validation {
    condition     = var.health_check.port == "traffic-port" || can(regex("^[0-9]+$", var.health_check.port))
    error_message = "Health port must be traffic-port or a numeric port. Bootstrap must serve that port too if overridden."
  }
  validation {
    condition     = var.health_check.port == "traffic-port" || var.health_check.port == tostring(var.container_port)
    error_message = "The bootstrap health port must match container_port or use traffic-port."
  }
}
variable "autoscaling" {
  type = object({
    enabled            = optional(bool, false)
    min_capacity       = optional(number, 1)
    max_capacity       = optional(number, 4)
    cpu_target         = optional(number, 60)
    memory_target      = optional(number)
    scale_in_cooldown  = optional(number, 300)
    scale_out_cooldown = optional(number, 60)
    disable_scale_in   = optional(bool, false)
  })
  default = {}
  validation {
    condition     = var.autoscaling.min_capacity >= 1 && var.autoscaling.max_capacity >= var.autoscaling.min_capacity && floor(var.autoscaling.min_capacity) == var.autoscaling.min_capacity && floor(var.autoscaling.max_capacity) == var.autoscaling.max_capacity
    error_message = "CPU/memory scaling requires integer capacities with max >= min >= 1."
  }
  validation {
    condition     = !var.autoscaling.enabled || (var.autoscaling.cpu_target != null || var.autoscaling.memory_target != null)
    error_message = "Enabled autoscaling requires a CPU or memory target."
  }
}
variable "ecr" {
  type = object({
    immutable_tags  = optional(bool, true)
    scan_on_push    = optional(bool, true)
    encryption_type = optional(string, "AES256")
    kms_key_arn     = optional(string)
    retain_images   = optional(number, 30)
    force_delete    = optional(bool, false)
  })
  default = {}
  validation {
    condition     = contains(["AES256", "KMS"], var.ecr.encryption_type) && var.ecr.retain_images >= 1 && floor(var.ecr.retain_images) == var.ecr.retain_images
    error_message = "Use AES256/KMS encryption and a positive integer image retention count."
  }
}
variable "iam" {
  type = object({
    task_policy_file         = optional(string)
    task_managed_policy_arns = optional(set(string), [])
    permissions_boundary_arn = optional(string)
  })
  default = {}
  validation {
    condition     = var.iam.task_policy_file == null ? true : can(regex("^policies/[a-zA-Z0-9_-]+\\.json$", var.iam.task_policy_file))
    error_message = "task_policy_file must be policies/filename.json relative to apps/<application> (no traversal), or null to omit the app policy."
  }
}
variable "secret" {
  description = "Create secret metadata only. Default name: <project>/<environment>/<application>/secrets. values and injection are managed separately."
  type = object({
    create                  = optional(bool, true)
    name                    = optional(string)
    description             = optional(string, "Application configuration; populate securely before first application deployment")
    recovery_window_in_days = optional(number, 30)
  })
  default = {}


  validation {
    condition     = var.secret.recovery_window_in_days >= 7 && var.secret.recovery_window_in_days <= 30
    error_message = "Secret recovery window must be 7-30 days."
  }
  validation {
    condition     = var.secret.name == null ? true : can(regex("^[a-zA-Z0-9/_+=.@-]{1,512}$", var.secret.name))
    error_message = "Secret name overrides must be 1-512 characters using letters, digits, or /_+=.@-. Omit name to use the standard convention."
  }
}
variable "logging" {
  type = object({
    retention_in_days = optional(number, 14)
    kms_key_arn       = optional(string)
    skip_destroy      = optional(bool, false)
  })
  default = {}
}
variable "monitoring" {
  type = object({
    enabled                       = optional(bool, false)
    cpu_threshold                 = optional(number, 80)
    memory_threshold              = optional(number, 80)
    target_5xx_threshold          = optional(number, 5)
    period                        = optional(number, 60)
    evaluation_periods            = optional(number, 3)
    datapoints_to_alarm           = optional(number, 2)
    treat_missing_data            = optional(string, "breaching")
    target_5xx_treat_missing_data = optional(string, "notBreaching")
    actions_enabled               = optional(bool, true)
    notify_recovery               = optional(bool, true)
  })
  default = {}
  validation {
    condition     = contains(["breaching", "notBreaching", "ignore", "missing"], var.monitoring.treat_missing_data) && contains(["breaching", "notBreaching", "ignore", "missing"], var.monitoring.target_5xx_treat_missing_data) && var.monitoring.datapoints_to_alarm >= 1 && var.monitoring.evaluation_periods >= var.monitoring.datapoints_to_alarm && var.monitoring.period >= 60 && var.monitoring.period % 60 == 0
    error_message = "Use a valid missing-data policy, whole-minute period and 1 <= datapoints <= evaluation periods."
  }
}


variable "lb_enabled" {
  type        = bool
  default     = false
  description = "Attach the application to an existing ALB when true. No ALB is created."
}
