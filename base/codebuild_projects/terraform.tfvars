aws_account_id = "270654520169"
aws_region     = "us-east-1"
project_prefix = "ecs-cicd-tutorial"

# Existing connection: copy its ARN from AWS Developer Tools > Settings > Connections.
github_connection_arn = "arn:aws:codeconnections:us-east-1:270654520169:connection/d1045901-cd12-4c58-ac71-e13339f8c1c4"

# Replace these proposed names with repositories you actually create on GitHub.
# Remove an entry if you only want one project. No split by operation is required.
runner_projects = {
  infrastructure = {
    repository = "Ovvi-Wan/ecs-cicd-demo"
  }
  application = {
    repository      = "Ovvi-Wan/ecs-cicd-tutorial-application"
    privileged_mode = true # Container image builds; omit if not needed.
  }
}
