# Application routing only. The ALB and listener are existing data sources.
resource "aws_lb_target_group" "app" {
  count                = var.lb_enabled ? 1 : 0
  name_prefix          = "app-"
  tags                 = { Name = "${var.name}-tg" }
  port                 = var.port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = var.load_balancer.deregistration_delay
  slow_start           = var.load_balancer.slow_start
  health_check {
    enabled             = true
    path                = var.health_check.path
    port                = var.health_check.port
    protocol            = "HTTP"
    matcher             = var.health_check.matcher
    interval            = var.health_check.interval
    timeout             = var.health_check.timeout
    healthy_threshold   = var.health_check.healthy_threshold
    unhealthy_threshold = var.health_check.unhealthy_threshold
  }
  lifecycle { create_before_destroy = true }
}
resource "aws_lb_listener_rule" "app" {
  for_each     = var.lb_enabled ? var.load_balancer.rules : {}
  listener_arn = var.alb_listener_arn
  priority     = each.value.priority
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }
  dynamic "condition" {
    for_each = length(each.value.path_patterns) > 0 ? [each.value.path_patterns] : []
    content {
      path_pattern { values = condition.value }
    }
  }
  dynamic "condition" {
    for_each = length(each.value.host_headers) > 0 ? [each.value.host_headers] : []
    content {
      host_header { values = condition.value }
    }
  }
}
