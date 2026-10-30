output "name" { value = local.service.name }
output "arn" { value = local.service.id }
output "security_group_id" { value = aws_security_group.task.id }
output "task_definition_arn" { value = aws_ecs_task_definition.app.arn }
output "task_definition_family" { value = aws_ecs_task_definition.app.family }

output "log_group_arn" { value = aws_cloudwatch_log_group.app.arn }
output "secret_arn" { value = try(aws_secretsmanager_secret.app[0].arn, null) }


output "target_group_arn" { value = var.lb_enabled ? aws_lb_target_group.app[0].arn : null }
output "target_group_arn_suffix" { value = var.lb_enabled ? aws_lb_target_group.app[0].arn_suffix : null }
