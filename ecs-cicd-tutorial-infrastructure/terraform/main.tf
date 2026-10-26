# Shared application root. ECS resources will be added in the next step.
# ECR remains owned by the application delivery pipeline.
locals {
  # Match the per-app backend key supplied by the workflows during initialization.
  state_key = "infrastructure/${var.application}/terraform.tfstate"
  name      = "ecs-cicd-tutorial-${var.application}"
}
