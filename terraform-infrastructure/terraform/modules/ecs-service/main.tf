locals {
  service         = one(concat(aws_ecs_service.fixed[*], aws_ecs_service.scaled[*]))
  alb_ports       = var.lb_enabled ? toset([tostring(var.port), var.health_check.port == "traffic-port" ? tostring(var.port) : var.health_check.port]) : toset([])
  scaling_metrics = { for key, value in { cpu = var.scaling.cpu_target, memory = var.scaling.memory_target } : key => value if var.scaling.enabled && value != null }
}
resource "aws_security_group" "task" {
  name_prefix = "${var.name}-task-"
  tags        = { Name = "${var.name}-task-sg" }
  description = "Fargate tasks for ${var.name}"
  vpc_id      = var.vpc_id
  lifecycle { create_before_destroy = true }
}

# Existing ALB security groups are owned elsewhere: their owner must allow task/health egress.
resource "aws_vpc_security_group_ingress_rule" "alb" {
  for_each                     = local.alb_ports
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
}

resource "aws_vpc_security_group_ingress_rule" "extra" {
  for_each                     = var.network.task_ingress
  security_group_id            = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.source_security_group_id
  description                  = each.value.description
}
resource "aws_vpc_security_group_egress_rule" "task" {
  for_each                     = var.network.task_egress
  security_group_id            = aws_security_group.task.id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.destination_security_group_id
  description                  = each.value.description
}
# Terraform registers the infrastructure-defined task revisions. Application
# releases copy the latest ACTIVE revision in this same family, replace the
# image/startup settings, then register and deploy their own revision.
# Keep this resource managed normally; only the service ignores task_definition.
resource "aws_ecs_task_definition" "app" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task.cpu
  memory                   = var.task.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  # Retain revisions for rollback. Both pipelines register revisions in this family.
  skip_destroy = true
  track_latest = false # Track the Terraform-owned revision, not application-created revisions.
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.task.architecture
  }
  # Omit this block to use Fargate's included 20 GiB.
  dynamic "ephemeral_storage" {
    for_each = var.task.ephemeral_storage_gib == null ? [] : [var.task.ephemeral_storage_gib]
    content { size_in_gib = ephemeral_storage.value }
  }
  container_definitions = jsonencode([{
    name         = var.container_name
    image        = "docker.io/hashicorp/http-echo:1.0.0" # Shared bootstrap image, not app-specific.
    essential    = true
    command      = ["-listen=:${var.port}", "-text=Application awaiting deployment"]
    portMappings = [{ containerPort = var.port, hostPort = var.port, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options   = { awslogs-group = aws_cloudwatch_log_group.app.name, awslogs-region = var.region, awslogs-stream-prefix = "bootstrap" }
    }
  }])
}
# Terraform requires a static lifecycle.ignore_changes list. These two service
# blocks are mutually exclusive: count creates exactly ONE ECS service.
# Fixed mode manages desired_count; scaled mode lets Application Auto Scaling own it.
resource "aws_ecs_service" "fixed" {
  count                              = var.scaling.enabled ? 0 : 1
  name                               = var.name
  cluster                            = var.cluster_arn
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = var.config.platform_version
  deployment_minimum_healthy_percent = var.config.minimum_healthy_percent
  deployment_maximum_percent         = var.config.maximum_percent
  health_check_grace_period_seconds  = var.lb_enabled ? var.config.health_check_grace_period_seconds : null
  wait_for_steady_state              = var.config.wait_for_steady_state
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  deployment_circuit_breaker {
    enable   = true
    rollback = var.config.rollback
  }
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = concat([aws_security_group.task.id], tolist(var.network.additional_task_security_group_ids))
    assign_public_ip = false
  }
  dynamic "load_balancer" {
    for_each = var.lb_enabled ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.app[0].arn
      container_name   = var.container_name
      container_port   = var.port
    }
  }
  lifecycle {
    # Registering infrastructure revisions must not replace the running app.
    # The application pipeline deploys a new revision based on the latest family revision.
    ignore_changes = [task_definition]
    precondition {
      condition     = length(var.subnet_ids) > 0
      error_message = "No task subnets found. Check the VPC selection and Tier tags used by the subnet data source."
    }
    precondition {
      condition     = !var.scaling.enabled || (var.desired_count >= var.scaling.min_capacity && var.desired_count <= var.scaling.max_capacity)
      error_message = "Initial desired_count must be within autoscaling min/max."
    }
  }
  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
  depends_on = [aws_lb_listener_rule.app, aws_vpc_security_group_ingress_rule.alb, aws_vpc_security_group_ingress_rule.extra, aws_vpc_security_group_egress_rule.task]
}
# A second block is necessary to ignore desired_count only when autoscaling is
# enabled. It does NOT create a second service alongside fixed. See README for
# the state-address migration required when switching an existing app's mode.
resource "aws_ecs_service" "scaled" {
  count                              = var.scaling.enabled ? 1 : 0
  name                               = var.name
  cluster                            = var.cluster_arn
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = var.config.platform_version
  deployment_minimum_healthy_percent = var.config.minimum_healthy_percent
  deployment_maximum_percent         = var.config.maximum_percent
  health_check_grace_period_seconds  = var.lb_enabled ? var.config.health_check_grace_period_seconds : null
  wait_for_steady_state              = var.config.wait_for_steady_state
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  deployment_circuit_breaker {
    enable   = true
    rollback = var.config.rollback
  }
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = concat([aws_security_group.task.id], tolist(var.network.additional_task_security_group_ids))
    assign_public_ip = false
  }
  dynamic "load_balancer" {
    for_each = var.lb_enabled ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.app[0].arn
      container_name   = var.container_name
      container_port   = var.port
    }
  }
  lifecycle {
    # App pipeline owns service deployments; autoscaling owns the live task count.
    ignore_changes = [task_definition, desired_count]
    precondition {
      condition     = length(var.subnet_ids) > 0
      error_message = "No task subnets found. Check the VPC selection and Tier tags used by the subnet data source."
    }
    precondition {
      condition     = !var.scaling.enabled || (var.desired_count >= var.scaling.min_capacity && var.desired_count <= var.scaling.max_capacity)
      error_message = "Initial desired_count must be within autoscaling min/max."
    }
  }
  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
  depends_on = [aws_lb_listener_rule.app, aws_vpc_security_group_ingress_rule.alb, aws_vpc_security_group_ingress_rule.extra, aws_vpc_security_group_egress_rule.task]
}
resource "aws_appautoscaling_target" "service" {
  count              = var.scaling.enabled ? 1 : 0
  min_capacity       = var.scaling.min_capacity
  max_capacity       = var.scaling.max_capacity
  resource_id        = "service/${var.cluster_name}/${local.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "target" {
  for_each           = local.scaling_metrics
  name               = "${var.name}-${each.key}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[0].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = each.value
    scale_in_cooldown  = var.scaling.scale_in_cooldown
    scale_out_cooldown = var.scaling.scale_out_cooldown
    disable_scale_in   = var.scaling.disable_scale_in
    predefined_metric_specification {
      predefined_metric_type = each.key == "cpu" ? "ECSServiceAverageCPUUtilization" : "ECSServiceAverageMemoryUtilization"
    }
  }
}
