output "alb_name" {
  description = "Use as load_balancer.existing_name in the selected app's app.tfvars."
  value       = aws_lb.shared.name
}
output "alb_arn" {
  value = aws_lb.shared.arn
}
output "alb_dns_name" {
  value = aws_lb.shared.dns_name
}
output "http_url" {
  value = "http://${aws_lb.shared.dns_name}"
}
output "http_listener_arn" {
  value = aws_lb_listener.http.arn
}
output "security_group_id" {
  value = aws_security_group.alb.id
}
output "vpc_id" {
  value = data.aws_vpc.selected.id
}
