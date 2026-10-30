output "cluster_name" { value = data.aws_ecs_cluster.shared.cluster_name }
output "cluster_arn" { value = data.aws_ecs_cluster.shared.arn }
output "vpc_id" { value = data.aws_vpc.selected.id }
output "task_subnet_ids" {
  value = toset(data.aws_subnets.tasks.ids)
}
output "load_balancer" {
  description = "Resolved existing ALB details, or null when running without an ALB."
  value = var.lb_enabled ? {
    arn_suffix   = data.aws_lb.existing[0].arn_suffix
    dns_name     = data.aws_lb.existing[0].dns_name
    listener_arn = data.aws_lb_listener.existing[0].arn
    # Any SG attached to the ALB can identify it as the source in task ingress.
    security_group_id = sort(tolist(data.aws_lb.existing[0].security_groups))[0]
  } : null
}
