output "deployment_target" {
  description = "Selected target; this checkpoint creates no AWS resources."
  value = {
    application   = var.application
    state_key     = local.state_key
    desired_count = var.desired_count
  }
  precondition {
    condition     = terraform.workspace == "default"
    error_message = "Use the default workspace. Each app is isolated by its backend key supplied during initialization."
  }
}
