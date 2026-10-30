# DOCUMENTATION ONLY. All workflow discovery excludes app-example, including run_all.
# Copy this folder to apps/<your-app>, change application, and create the GitHub environment.
# Terraform rejects application="app-example" even when invoked manually.
# ALB and its HTTP listener must already exist; this job never creates either.
# These are ALL supported root inputs and nested options, not arbitrary provider options.
# Null means unset; optional fields can usually be omitted to use their documented defaults.
application    = "app-example"
aws_region     = "us-east-1"
project_prefix = "ecs-cicd-tutorial" # Must match runner IAM resource-name scope.
environment    = "dev"               # One state per application; use unique app directories for multiple environments.
tags           = { Owner = "platform", CostCenter = "demo" }
cluster_name   = "ecs-cicd-tutorial-dev" # Existing cluster, never created by this app root.

network = {
  vpc_id                             = null                    # Alternative: "vpc-0123456789abcdef0" and set vpc_name=null.
  vpc_name                           = "ecs-cicd-tutorial-dev" # Name tag; exactly one VPC must match.
  additional_task_security_group_ids = []                      # Additional existing SGs; managed task SG always attached.
  task_ingress                       = {}                      # ALB-to-task ingress is automatic. Example for workers/direct callers:
  # task_ingress = {
  #   peer = { port = 8080, source_security_group_id = "sg-0123456789abcdef0", cidr_ipv4 = null, description = "Trusted caller" }
  #   diagnostics = { port = 9090, cidr_ipv4 = "10.0.0.0/16", source_security_group_id = null, description = "Internal diagnostics" }
  # }
  task_egress = {
    all = {
      protocol                      = "-1" # All protocols. For TCP use "tcp" with from_port/to_port.
      from_port                     = null
      to_port                       = null
      cidr_ipv4                     = "0.0.0.0/0" # Exactly one CIDR or destination SG per rule.
      destination_security_group_id = null
      description                   = "Outbound access through NAT"
    }
  } # {} denies outbound traffic; image pulls, logs and secrets require reachable endpoints.
}

container_name = "app" # Keep stable in the application pipeline and service load-balancer binding.
container_port = 8080  # REAL app's port. Drives placeholder, task mapping, SG and target group.
desired_count  = 1     # Managed by Terraform when autoscaling disabled; initial count when enabled.
task = {
  cpu                   = 256      # CPU units; 1024 = 1 vCPU. Valid Fargate combinations validated.
  memory                = 512      # MiB, not GiB.
  architecture          = "X86_64" # Or ARM64; BOTH bootstrap and real images must support it.
  ephemeral_storage_gib = null     # Omit/null for included 20 GiB; set 21-200 only when needed.
}
service = {
  platform_version                  = "1.4.0" # Or LATEST. Linux Fargate only.
  minimum_healthy_percent           = 100
  maximum_percent                   = 200 # Allows replacement task to start before old task stops.
  health_check_grace_period_seconds = 60
  rollback                          = true # Circuit breaker enabled; rollback requires previous completed deployment.
  wait_for_steady_state             = true
}

lb_enabled = true # false for applications without an ALB.
load_balancer = {
  existing_name        = "replace-with-existing-alb"                                                 # Required when lb_enabled=true; ALB and HTTP listener must already exist.
  listener_port        = 80                                                                          # Existing HTTP listener to look up; never creates a listener.
  deregistration_delay = 30                                                                          # Seconds to drain in-flight requests.
  slow_start           = 0                                                                           # Seconds, 0 disables; otherwise 30-900.
  rules                = { app = { priority = 100, path_patterns = ["/app/*"], host_headers = [] } } # Required when lb_enabled=true.
  # Existing ALB SG owner must allow outbound traffic to this app port.
  # Required when lb_enabled=true. Priorities must be unique ACROSS all apps on a shared listener.
  # rules = {
  #   billing = { priority = 100, path_patterns = ["/billing/*"], host_headers = [] }
  #   hostname = { priority = 110, path_patterns = [], host_headers = ["billing.example.com"] }
  # }
  # Conditions within a rule are ANDed; values in one condition are ORed. No DNS records created.
}
health_check = {
  path                = "/health"      # Must also work in real app. Public http-echo returns success here.
  port                = "traffic-port" # Or same numeric container_port string. Bootstrap has only one listening port.
  matcher             = "200"
  interval            = 30
  timeout             = 5 # Less than interval.
  healthy_threshold   = 2
  unhealthy_threshold = 3
}
autoscaling = {
  enabled            = false # Decide at onboarding; switching requires state-address migration (see README).
  min_capacity       = 1     # CPU/memory scaling needs >=1; scale-from-zero is not implemented.
  max_capacity       = 4
  cpu_target         = 60   # null disables CPU policy.
  memory_target      = null # e.g. 70; at least one policy required when enabled.
  scale_in_cooldown  = 300
  scale_out_cooldown = 60
  disable_scale_in   = false
}
ecr = {
  immutable_tags  = true
  scan_on_push    = true     # Registry-level scan configuration can affect scanning behavior.
  encryption_type = "AES256" # Or KMS.
  kms_key_arn     = null     # Optional existing key for KMS; key policy must authorize use.
  retain_images   = 30       # Retains newest images across tags; size this for rollback needs.
  force_delete    = false    # Keep false to avoid deleting non-empty repository accidentally.
}
iam = {
  task_policy_file         = "policies/task-policy.json" # One JSON file relative to this app directory; null or omitted for no app policy.
  task_managed_policy_arns = []                          # Existing customer/AWS managed policies for task role.
  permissions_boundary_arn = null                        # Existing boundary applied to execution AND task roles.
}
secret = {
  create                  = true # Secret metadata only. No secret version/value is managed by Terraform.
  name                    = null # Default <project>/<environment>/<application>/secrets. Override only for legacy names or integrations.
  description             = "Populate securely before deploying the real application"
  recovery_window_in_days = 30 # 7-30; no immediate deletion option.
  # Populate values securely outside Terraform. The application pipeline handles injection.
}
logging = {
  retention_in_days = 14    # CloudWatch supported retention interval; 0 means never expire.
  kms_key_arn       = null  # Existing CMK with a policy permitting regional CloudWatch Logs use.
  skip_destroy      = false # true retains logs when app infrastructure is destroyed.
}
monitoring = {
  enabled                       = true # Creates SNS topic + alarms, no subscriptions or Container Insights.
  cpu_threshold                 = 80   # Percent. CPU/memory use Average.
  memory_threshold              = 80
  target_5xx_threshold          = 5  # Per-period Sum for this TG; created only when lb_enabled=true.
  period                        = 60 # Seconds; multiple of 60.
  evaluation_periods            = 3
  datapoints_to_alarm           = 2
  treat_missing_data            = "breaching"    # CPU/memory: alert when metrics stop arriving.
  target_5xx_treat_missing_data = "notBreaching" # AWS emits 5xx only for nonzero errors; missing is normal.
  actions_enabled               = true
  notify_recovery               = true # Publish OK transitions to same topic.
}
