variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project_prefix" {
  type    = string
  default = "ecs-cicd-tutorial"
}
variable "environment" {
  type    = string
  default = "dev"
}
resource "aws_ecs_cluster" "shared" {
  name = "${var.project_prefix}-${var.environment}"
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}
output "cluster_name" { value = aws_ecs_cluster.shared.name }
output "cluster_arn" { value = aws_ecs_cluster.shared.arn }
