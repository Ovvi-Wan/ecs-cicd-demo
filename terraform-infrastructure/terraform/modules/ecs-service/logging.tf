resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.logging.retention_in_days
  kms_key_id        = var.logging.kms_key_arn
  skip_destroy      = var.logging.skip_destroy
}
