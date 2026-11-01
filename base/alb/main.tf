locals {
  name = "${var.project_prefix}-${var.environment}-alb"
}

data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = [coalesce(var.vpc_name, "${var.project_prefix}-${var.environment}")]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "tag:Tier"
    values = ["public"]
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-"
  description = "Shared HTTP ALB; application and health-check egress only"
  vpc_id      = data.aws_vpc.selected.id
  tags        = { Name = "${local.name}-sg" }
  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each          = var.allowed_http_cidrs
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "targets" {
  for_each          = toset([for port in var.target_ports : tostring(port)])
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = data.aws_vpc.selected.cidr_block
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
}

resource "aws_lb" "shared" {
  name                       = local.name
  internal                   = false
  load_balancer_type         = "application"
  ip_address_type            = "ipv4"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = sort(data.aws_subnets.public.ids)
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true

  lifecycle {
    precondition {
      condition     = length(local.name) <= 32 && can(regex("^[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9]$", local.name)) && !startswith(local.name, "internal-")
      error_message = "The generated ALB name must be valid and at most 32 characters. Shorten project_prefix or environment."
    }
    precondition {
      condition     = length(data.aws_subnets.public.ids) >= 2 && length(distinct([for subnet in data.aws_subnet.public : subnet.availability_zone])) == length(data.aws_subnets.public.ids)
      error_message = "Select at least two Tier=public subnets, with exactly one subnet per Availability Zone."
    }
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.shared.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No application route matched"
      status_code  = "404"
    }
  }
}
