# Shared ECS cluster

Optional foundation root. Apply once before application infrastructure if the
shared cluster does not already exist. If it exists, use its name in app.tfvars
instead, or import it before applying this root. Never recreate an existing
cluster under a second state. No network or application resources live here.

Default name: ecs-cicd-tutorial-dev. Container Insights is explicitly disabled.
Apps use the FARGATE launch type; no EC2 capacity or Fargate Spot is configured.
Review the backend bucket/key and region before init/plan/apply on your bootstrap
runner. This root is not deployed by application workflows.
