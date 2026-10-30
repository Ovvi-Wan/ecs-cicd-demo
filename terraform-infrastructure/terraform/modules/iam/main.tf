variable "name" { type = string }
variable "config" { type = any }
variable "repository_arn" { type = string }
variable "log_group_arn" { type = string }
variable "secret_enabled" { type = bool }
variable "secret_arn" { type = string }
variable "policies" {
  type = map(string)
  validation {
    condition     = alltrue([for policy in values(var.policies) : can(jsondecode(policy).Statement)])
    error_message = "Each policy must be valid JSON with a Statement field."
  }
}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}
resource "aws_iam_role" "execution" {
  name                 = "${var.name}-execution"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  permissions_boundary = var.config.permissions_boundary_arn
}
resource "aws_iam_role" "task" {
  name                 = "${var.name}-task"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  permissions_boundary = var.config.permissions_boundary_arn
}
data "aws_iam_policy_document" "execution" {
  statement {
    sid       = "ECRAuthentication"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid       = "PullApplicationImage"
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
    resources = [var.repository_arn]
  }
  statement {
    sid       = "WriteApplicationLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${var.log_group_arn}:*"]
  }
  dynamic "statement" {
    for_each = var.secret_enabled ? [1] : []
    content {
      sid       = "ReadConfiguredSecrets"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [var.secret_arn]
    }
  }
}
resource "aws_iam_role_policy" "execution" {
  name   = "task-startup"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}
resource "aws_iam_policy" "app" {
  for_each = var.policies
  name     = "${var.name}-${trimsuffix(basename(each.key), ".json")}"
  policy   = each.value
}
resource "aws_iam_role_policy_attachment" "app" {
  for_each   = var.policies
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.app[each.key].arn
}
resource "aws_iam_role_policy_attachment" "existing" {
  for_each   = var.config.task_managed_policy_arns
  role       = aws_iam_role.task.name
  policy_arn = each.value
}
output "execution_role_arn" {
  value      = aws_iam_role.execution.arn
  depends_on = [aws_iam_role_policy.execution]
}
output "task_role_arn" {
  value      = aws_iam_role.task.arn
  depends_on = [aws_iam_role_policy_attachment.app, aws_iam_role_policy_attachment.existing]
}
