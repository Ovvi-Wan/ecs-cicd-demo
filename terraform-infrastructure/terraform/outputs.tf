output "deployment_target" {
  value = {
    application            = var.application
    state_key              = local.state_key
    cluster_name           = module.data_sources.cluster_name
    service_name           = module.ecs.name
    service_arn            = module.ecs.arn
    repository_url         = module.ecr.url
    task_security_group_id = module.ecs.security_group_id
    alb_security_group_id  = try(module.data_sources.load_balancer.security_group_id, null)
    alb_dns_name           = try(module.data_sources.load_balancer.dns_name, null)
    target_group_arn       = module.ecs.target_group_arn
    task_role_arn          = module.iam.task_role_arn
    execution_role_arn     = module.iam.execution_role_arn
    secret_arn             = module.ecs.secret_arn
    sns_topic_arn          = module.monitoring.sns_topic_arn
    task_definition_arn    = module.ecs.task_definition_arn
    task_definition_family = module.ecs.task_definition_family
  }
}
