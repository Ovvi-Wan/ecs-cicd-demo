# CodeBuild runner projects

This root creates projects, runner IAM roles/policies, CloudWatch logs and
WORKFLOW_JOB_QUEUED webhooks. It consumes an existing authorized CodeConnections
connection rather than creating that connection.

## Point runners at the monorepo

The current terraform.tfvars still names the old split repositories. Before enabling
CI, authorize CodeConnections for Ovvi-Wan/ecs-cicd-demo and update repository values
in runner_projects to that name. Keep infrastructure/application map keys stable:
IAM policies reference them and changing keys may replace resources. Two runner
projects can serve the same repository with different IAM roles.

The workflow templates retain the existing infrastructure runner label:

```yaml
runs-on: codebuild-ecs-cicd-tutorial-infrastructure-${{ github.run_id }}-${{ github.run_attempt }}
```

Review and apply base changes on an approved bootstrap execution environment:

```bash
# Working directory: base/codebuild_projects
terraform init
terraform plan -out=codebuild.tfplan
# Review repository mappings, IAM permissions and replacements first.
terraform apply codebuild.tfplan
terraform output runner_project_names
```

Build and queue timeouts currently equal 15 minutes. Workflow jobs allow 30 minutes;
align them before longer jobs. Native environment approvals wait before assigning
the apply job to CodeBuild, so approval waits do not consume CodeBuild build time.

The role policies include infrastructure deployment, state and ECR permissions;
they are not logging-only. Review main.tf for authoritative permissions. The existing
LIFECYCLE variable is unused by the one-configuration-per-app workflows.
No Docker-based approval action is used. The backend bucket must already exist.
See [root setup](../../README.md) before activating workflow templates.

## Fargate application infrastructure additions

Apply the current base configuration before enabling the app infrastructure jobs.
The infrastructure runner now needs SNS topic/policy management and IAM permissions
boundary updates. Application delivery can register ECS task definitions, update
project-prefixed services and pass project task roles. CodeBuild build timeout is
35 minutes, allowing the 30-minute workflow job to finish or time out first.
The infrastructure repository mapping is Ovvi-Wan/ecs-cicd-demo; project keys/names
are unchanged. The application repository mapping remains separate.
No SSM Parameter Store permissions are added. Optional customer KMS configurations
require explicit runner/key-policy grants scoped to the chosen keys.
