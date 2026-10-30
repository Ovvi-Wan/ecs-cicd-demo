variable "name" { type = string }
variable "cluster_name" { type = string }
variable "service_name" { type = string }
variable "config" { type = any }
variable "lb_enabled" { type = bool }
variable "alb_arn_suffix" { type = string }
variable "target_group_arn_suffix" { type = string }
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
locals {
  metrics = merge({
    cpu    = { namespace = "AWS/ECS", metric = "CPUUtilization", statistic = "Average", threshold = var.config.cpu_threshold, dimensions = { ClusterName = var.cluster_name, ServiceName = var.service_name } }
    memory = { namespace = "AWS/ECS", metric = "MemoryUtilization", statistic = "Average", threshold = var.config.memory_threshold, dimensions = { ClusterName = var.cluster_name, ServiceName = var.service_name } }
    }, var.lb_enabled ? {
    target-5xx = { namespace = "AWS/ApplicationELB", metric = "HTTPCode_Target_5XX_Count", statistic = "Sum", threshold = var.config.target_5xx_threshold, dimensions = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix } }
  } : {})
}
resource "aws_sns_topic" "alarms" {
  count = var.config.enabled ? 1 : 0
  name  = "${var.name}-alarms"
}
data "aws_iam_policy_document" "sns" {
  count = var.config.enabled ? 1 : 0
  statement {
    sid       = "AllowCloudWatchAlarms"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms[0].arn]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudwatch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:alarm:${var.name}-*"]
    }
  }
}
resource "aws_sns_topic_policy" "alarms" {
  count  = var.config.enabled ? 1 : 0
  arn    = aws_sns_topic.alarms[0].arn
  policy = data.aws_iam_policy_document.sns[0].json
}
resource "aws_cloudwatch_metric_alarm" "service" {
  for_each            = var.config.enabled ? local.metrics : {}
  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = "${each.key} for application ${var.name}."
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  statistic           = each.value.statistic
  dimensions          = each.value.dimensions
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  period              = var.config.period
  evaluation_periods  = var.config.evaluation_periods
  datapoints_to_alarm = var.config.datapoints_to_alarm
  treat_missing_data  = each.key == "target-5xx" ? var.config.target_5xx_treat_missing_data : var.config.treat_missing_data
  actions_enabled     = var.config.actions_enabled
  alarm_actions       = [aws_sns_topic.alarms[0].arn]
  ok_actions          = var.config.notify_recovery ? [aws_sns_topic.alarms[0].arn] : []
  depends_on          = [aws_sns_topic_policy.alarms]
}
output "sns_topic_arn" { value = try(aws_sns_topic.alarms[0].arn, null) }
