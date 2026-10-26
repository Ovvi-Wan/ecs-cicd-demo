output "github_connection_arn" {
  value = var.github_connection_arn
}
output "runner_project_names" {
  value = { for key, project in aws_codebuild_project.runner : key => project.name }
}
