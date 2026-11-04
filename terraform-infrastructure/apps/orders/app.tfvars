# Deploy base/network_infrastructure and base/ecs_cluster first, or change these selectors.
application  = "orders"
cluster_name = "ecs-cicd-tutorial-dev"
network = {
  vpc_name = "ecs-cicd-tutorial-dev"
  # Discovers private task subnets by Tier tags.
}
# Real app port: drives the task SG and target group as well as the placeholder.
container_port = 3000
lb_enabled     = true # false for applications without an ALB.
load_balancer = {
  existing_name = "ecs-cicd-tutorial-dev-alb"
  rules         = { app = { priority = 200, path_patterns = ["/orders", "/orders/*"] } }
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
# Shared defaults: one task, 256 CPU / 512 MiB, included 20 GiB, /health,
# private subnets, app secret metadata, and CPU/memory alarms.
# TG 5xx is enabled because lb_enabled=true. Override settings only when needed.
# Set iam.task_policy_file to one JSON policy path; omit for no app policy.
