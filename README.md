# ECS CI/CD demo

Reusable per-application AWS ECS Fargate infrastructure with separate Terraform
state for each application and a shared deployment approval gate. Application builds/deployments are a
separate pipeline: infrastructure starts a public HTTP placeholder, then image
releases register task definitions and update the existing service.

## Layout

- [base/](base/README.md): state bucket, CodeBuild runner roles/projects, VPC, shared ALB and optional shared ECS cluster.
- [terraform-infrastructure/](terraform-infrastructure/README.md): shared Terraform root, modules and per-app inputs.
- [app-example](terraform-infrastructure/apps/app-example/app.tfvars): every supported option with comments and IAM policy examples. Never selected by workflows.
- [.github/workflows/](.github/workflows/README.md): PR plans and post-merge infrastructure deployment; manual all-app template remains disabled.

The previous misspelled terraform-infrastucture directory was renamed. State keys
remain infrastructure/<app>/terraform.tfstate. CodeBuild runner project names
remain unchanged, so existing runner labels still work.

## Automation setup

`terraform-pr.yml` and `terraform-deploy.yml` are enabled in source. They select
apps affected by PRs targeting main and pushes to main, respectively. The manual
workflow remains `.yml.disabled`. No AWS apply was run as part of this implementation.

1. Verify/provision the state bucket and network foundation. If necessary create
   [base/ecs_cluster](base/ecs_cluster/README.md) once; apps only read that cluster.
   For ALB-enabled apps, provision [base/alb](base/alb/README.md) after the network
   and use its ALB name in the selected app configuration.
2. Review/apply base/codebuild_projects changes separately: infrastructure SNS and
   IAM-boundary permissions, application ECS deployment permissions, 35-minute
   runner timeout, and infrastructure repository mapping to Ovvi-Wan/ecs-cicd-demo.
   Authorize that repository on the existing CodeConnection. The separate
   application repository mapping is retained; change it if your app sources move.
3. Review billing/orders tfvars. Defaults select the base dev VPC by Name and
   subnets by Tier tags, and cluster ecs-cicd-tutorial-dev. No invented VPC IDs.
4. Configure one GitHub environment named terraform-apply with required reviewers
   and main-only deployment branches. The existing workflow templates retain their
   public-repository approval guard. Review GitHub plan support for your repository
   before activation. New apps automatically use this shared approval gate.
   Allow self-review to approve your own pushes; disable administrator bypass.
5. Runner tools: bash, git, jq, AWS CLI, gh, GNU date and sha256sum. Workflows install
   Terraform 1.16.4 with AWS provider 6.61.0. Run formatting and validation as documented in the infrastructure guide.
6. Commit and push the enabled PR/deploy workflows. Leave ENABLE_DEPLOYMENTS unset for
   plans only. After configuring the shared required reviewers, set repository Actions
   variables ENABLE_DEPLOYMENTS=true and TERRAFORM_APPROVAL_READY=true. Both are required.
   Review all selected app plans before approving terraform-apply in Review deployments.

App policy files and tfvars must contain no secret values. Saved binary plans and
Terraform outputs may contain environment variables: only put
non-secret values there. Plan artifacts expire after one day. No SSM parameters, subscriptions or Container Insights are created.

See the [infrastructure guide](terraform-infrastructure/README.md) for onboarding,
outputs, infrastructure scope, scaling ownership and validation commands.
