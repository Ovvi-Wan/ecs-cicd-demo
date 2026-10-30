resource "aws_secretsmanager_secret" "app" {
  count                   = var.secret.create ? 1 : 0
  name                    = var.secret_name
  description             = var.secret.description
  recovery_window_in_days = var.secret.recovery_window_in_days
}
