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
  existing_name = "replace-with-existing-alb" # Set the real ALB name before planning.
  rules         = { app = { priority = 200, path_patterns = ["/orders/*"] } }
}
# Shared defaults: one task, 256 CPU / 512 MiB, included 20 GiB, /health,
# private subnets, app secret metadata, and CPU/memory alarms.
# TG 5xx is enabled because lb_enabled=true. Override settings only when needed.
# Add app IAM files through iam.task_policy_files; defaults attach no app policies.
