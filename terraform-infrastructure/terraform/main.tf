module "data_sources" {
  source        = "./modules/data-sources"
  cluster_name  = var.cluster_name
  network       = var.network
  load_balancer = var.load_balancer
  lb_enabled    = var.lb_enabled
}
locals {
  name        = "${var.project_prefix}-${var.environment}-${var.application}"
  state_key   = "infrastructure/${var.application}/terraform.tfstate"
  secret_name = "${var.project_prefix}/${var.environment}/${var.application}/secrets"

  policies = { for filename in var.iam.task_policy_files : filename => file("${path.module}/../apps/${var.application}/${filename}") }
}
module "ecr" {
  source = "./modules/ecr"
  name   = local.name
  config = var.ecr
}
module "iam" {
  source         = "./modules/iam"
  name           = local.name
  config         = var.iam
  repository_arn = module.ecr.arn
  log_group_arn  = module.ecs.log_group_arn
  secret_enabled = var.secret.create
  secret_arn     = module.ecs.secret_arn
  policies       = local.policies
}

module "ecs" {
  source                = "./modules/ecs-service"
  name                  = local.name
  cluster_name          = module.data_sources.cluster_name
  cluster_arn           = module.data_sources.cluster_arn
  vpc_id                = module.data_sources.vpc_id
  subnet_ids            = module.data_sources.task_subnet_ids
  network               = var.network
  port                  = var.container_port
  container_name        = var.container_name
  task                  = var.task
  execution_role_arn    = module.iam.execution_role_arn
  task_role_arn         = module.iam.task_role_arn
  logging               = var.logging
  secret                = var.secret
  secret_name           = coalesce(var.secret.name, local.secret_name)
  region                = var.aws_region
  desired_count         = var.desired_count
  config                = var.service
  scaling               = var.autoscaling
  lb_enabled            = var.lb_enabled
  alb_security_group_id = try(module.data_sources.load_balancer.security_group_id, null)
  alb_listener_arn      = try(module.data_sources.load_balancer.listener_arn, null)
  load_balancer         = var.load_balancer
  health_check          = var.health_check
}
module "monitoring" {
  source                  = "./modules/monitoring"
  name                    = local.name
  cluster_name            = module.data_sources.cluster_name
  service_name            = module.ecs.name
  config                  = var.monitoring
  lb_enabled              = var.lb_enabled
  alb_arn_suffix          = try(module.data_sources.load_balancer.arn_suffix, null)
  target_group_arn_suffix = module.ecs.target_group_arn_suffix
}

