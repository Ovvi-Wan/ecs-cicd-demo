# ECS CI/CD demo

Reusable per-application AWS ECS Fargate infrastructure with separate Terraform
state and approval for each application. Application builds/deployments are a
separate pipeline: infrastructure starts a public HTTP placeholder, then image
releases register task definitions and update the existing service.

## Layout

- [base/](base/README.md): state bucket, CodeBuild runner roles/projects, VPC and optional shared ECS cluster.
- [terraform-infrastructure/](terraform-infrastructure/README.md): shared Terraform root, modules and per-app inputs.
- [app-example](terraform-infrastructure/apps/app-example/app.tfvars): every supported option with comments and IAM policy examples. Never selected by workflows.
- [.github/workflows/](.github/workflows/README.md): disabled PR, post-merge and manual all-app workflows.

The previous misspelled terraform-infrastucture directory was renamed. State keys
remain infrastructure/<app>/terraform.tfstate. CodeBuild runner project names
remain unchanged, so existing runner labels still work.

## Before enabling automation

All workflow templates still end in .yml.disabled. No AWS apply was run as part of
this implementation. Removing the suffix activates workflows; review setup first.

1. Verify/provision the state bucket and network foundation. If necessary create
   [base/ecs_cluster](base/ecs_cluster/README.md) once; apps only read that cluster.
2. Review/apply base/codebuild_projects changes separately: infrastructure SNS and
   IAM-boundary permissions, application ECS deployment permissions, 35-minute
   runner timeout, and infrastructure repository mapping to Ovvi-Wan/ecs-cicd-demo.
   Authorize that repository on the existing CodeConnection. The separate
   application repository mapping is retained; change it if your app sources move.
3. Review billing/orders tfvars. Defaults select the base dev VPC by Name and
   subnets by Tier tags, and cluster ecs-cicd-tutorial-dev. No invented VPC IDs.
4. Configure GitHub environments named billing and orders with required reviewers
   and main-only deployment branches. The existing workflow templates retain their
   public-repository approval guard. Review GitHub plan support for your repository
   before activation. Do not create an app-example environment.
5. Runner tools: bash, git, jq, AWS CLI, gh, GNU date and sha256sum. Workflows install
   Terraform 1.16.4 with AWS provider 6.61.0. Run formatting and validation as documented in the infrastructure guide.
6. Remove .disabled when ready to run plans. Leave ENABLE_DEPLOYMENTS unset for
   plans only; set it to true only after approval environments are configured.

App policy files and tfvars must contain no secret values. Saved binary plans and
Terraform outputs may contain environment variables: only put
non-secret values there. Plan artifacts expire after one day. No SSM parameters, subscriptions or Container Insights are created.

See the [infrastructure guide](terraform-infrastructure/README.md) for onboarding,
outputs, infrastructure scope, scaling ownership and validation commands.
