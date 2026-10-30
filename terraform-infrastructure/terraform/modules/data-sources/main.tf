# Read-only lookups. This module never creates or takes ownership of AWS resources.
data "aws_ecs_cluster" "shared" { cluster_name = var.cluster_name }

data "aws_vpc" "selected" {
  id = var.network.vpc_id
  dynamic "filter" {
    for_each = var.network.vpc_name == null ? [] : [var.network.vpc_name]
    content {
      name   = "tag:Name"
      values = [filter.value]
    }
  }
}
data "aws_subnets" "tasks" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "tag:Tier"
    values = ["private"]
  }
  lifecycle {
    postcondition {
      condition     = length(self.ids) > 0
      error_message = "No private task subnets matched the selected VPC and Tier=private tag. Check the VPC selection and subnet tags."
    }
  }
}
data "aws_lb" "existing" {
  count = var.lb_enabled ? 1 : 0
  name  = var.load_balancer.existing_name
  lifecycle {
    postcondition {
      condition     = self.vpc_id == data.aws_vpc.selected.id && self.load_balancer_type == "application" && length(self.security_groups) > 0
      error_message = "The existing load balancer must be an ALB in the selected VPC with a security group."
    }
  }
}
data "aws_lb_listener" "existing" {
  count             = var.lb_enabled ? 1 : 0
  load_balancer_arn = data.aws_lb.existing[0].arn
  port              = var.load_balancer.listener_port
  lifecycle {
    postcondition {
      condition     = self.protocol == "HTTP"
      error_message = "The selected ALB listener must use HTTP; TLS is not configured by this application root."
    }
  }
}
