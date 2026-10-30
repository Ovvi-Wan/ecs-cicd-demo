# Per-application Fargate infrastructure

## Configuration

The shared root is terraform/. Each app supplies apps/<app>/app.tfvars and uses
its own backend key: infrastructure/<app>/terraform.tfstate. Workflows enforce the
default workspace. The backend bucket/region live in terraform/versions.tf.

Copy [app-example](apps/app-example/app.tfvars) to onboard another application.
It lists every supported setting with comments and is excluded from every workflow.
Billing/orders contain a placeholder ALB name that must be replaced before planning.

The root connects these modules:

| Module | Responsibility |
| --- | --- |
| data-sources | Existing cluster, VPC, subnets, ALB and HTTP listener |
| ecr | Application repository and image retention |
| iam | Execution role, task role and policy attachments |
| ecs-service | App target group/listener rules, task SG, log group, secret metadata, bootstrap task, service and scaling |
| monitoring | CPU/memory/5xx alarms and an SNS topic without subscriptions |

Names use project_prefix-environment-application, limited to 46 characters.
See [the repository naming convention](../NAMING.md) for secrets, resource suffixes,
shared infrastructure, and migration guidance.
There is no automatic truncation or hashing. This setup supports Linux Fargate,
one essential application container and one target group per application.

## Network and load balancing

```hcl
network = {
  vpc_name = "ecs-cicd-tutorial-dev" # Or vpc_id, not both.
}
lb_enabled = true
load_balancer = {
  existing_name = "your-existing-alb"
  rules = { app = { priority = 100, path_patterns = ["/billing/*"] } }
}
```

All task subnets are discovered using the selected VPC and Tier=private tag.
Tasks never receive public IP addresses. Ensure tags reflect actual private routing;
tags alone do not establish it. Tasks need outbound access through NAT for the
Docker Hub bootstrap image. An internet-facing ALB can still serve these private tasks.

ALBs and listeners are never created. The existing HTTP listener defaults to port
80. Task SG ingress allows the ALB SG on container_port. The shared ALB owner manages
its SG egress, client ingress, subnets and internal/external visibility. Listener
priorities must be unique across apps. Path prefixes are not stripped automatically.
Set lb_enabled=false for workers without load balancing. No 5xx alarms are then created.

## Application secrets

Terraform creates one optional Secrets Manager secret per application:

```hcl
secret = { create = true }
```

The default name is `<project>/<environment>/<application>/secrets`, for example
`ecs-cicd-tutorial/dev/billing/secrets`. Use `secret.name` only for a legacy name
or an integration requirement. Changing an existing secret's name replaces it;
Terraform does not copy its value. Pin the existing name before applying if the
secret has already been deployed, then migrate values and consumers deliberately.

Only metadata is managed: name, description and recovery window.
Secrets use the default AWS-managed `aws/secretsmanager` key.
Populate values securely outside Terraform. The separate application pipeline will
own how secrets are supplied to the actual application. No secret values or injection
mappings belong in this job. The bootstrap task does not consume app secrets.

The execution role receives startup read access to the app secret.
Application SDK access requires a task-role policy.

## IAM policies

Put normal AWS IAM JSON files in apps/<app>/policies/ and list them in
`iam.task_policy_files`. Each file becomes a managed policy attached to the task
role. No templates or placeholders are expanded. See the [policy guide](apps/app-example/policies/README.md).

Execution permissions for ECR, logs and the application's secret are generated
automatically. Optional existing managed policies and a permissions boundary are
supported. Do not grant the application permissions it only needs for task startup.

## Infrastructure scope

1. Provision or verify the shared foundation. Apps read the existing cluster; the
   optional base/ecs_cluster root creates it separately with Container Insights off.
2. Configure the real application's port and ALB health endpoint in tfvars.
3. Review and apply the infrastructure plan. The public hashicorp/http-echo:1.0.0
   placeholder starts on that port and answers HTTP health checks.
4. Populate secret values securely outside Terraform when needed.

Terraform creates the initial placeholder task and service, and continues to own
CPU, memory, architecture, storage and task roles in its task-definition resource.
Both pipelines use the same family, project_prefix-environment-application.

The agreed release flow is:

1. Terraform registers a new revision when infrastructure task settings change.
2. The ECS service ignores task_definition changes, so this apply does not replace
   the running application with the placeholder.
3. The separate application pipeline reads the newest ACTIVE revision in that family,
   preserves infrastructure settings, replaces the image and applies its own command,
   entrypoint, environment, secret references and other application settings.
4. It registers another revision and updates the service to that exact returned ARN.

The application pipeline must replace the placeholder command, not only the image.
It must start from the latest family revision on every deployment rather than from
an old checked-in task definition. It should preserve task-level CPU/memory/storage
and roles. Container-level CPU/memory limits, if used, must fit the task size.

Infrastructure sizing changes take effect on the next APPLICATION deployment, not
immediately after Terraform apply. An application redeployment with the same image
can roll out new sizing without changing application code. Serialize both pipelines
per application so a release cannot read an old revision while Terraform creates a
new one. Select the base revision once and deploy the exact newly registered ARN.
The newest ACTIVE revision is not necessarily the currently running revision; this
workflow deliberately uses it to pick up new infrastructure settings.

The Terraform task resource does not ignore changes and uses track_latest=false;
it tracks its own revision. The service alone ignores task_definition. For scaled
services desired_count is also ignored so autoscaling can manage the running count.

The deployment_target output exposes the task family and Terraform-owned revision
alongside infrastructure IDs. No application task JSON artifact, SSM parameter or
application pipeline is created by this job. The application pipeline will be built
separately. Task revisions are retained for rollback and need cleanup when retired.

Omit task.ephemeral_storage_gib or use null for the included 20 GiB; use 21-200 only
when extra storage is needed. Port/health-path changes still require coordination
because the existing running app must match its infrastructure routing.

## Task count ownership

Exactly one ECS service is created. The fixed/scaled resource blocks are mutually
exclusive because lifecycle.ignore_changes must be static. Fixed mode lets Terraform
manage desired_count; scaled mode ignores it after creation so autoscaling can own it.
The reason is also commented above both blocks. CPU/memory scaling requires min >=1.

Choose scaling at onboarding. To change mode after deployment, serialize work for
that app and migrate its service state address on an authorized infrastructure runner:

```bash
# Initialize the correct app backend first, then change false -> true:
terraform state mv 'module.ecs.aws_ecs_service.fixed[0]' 'module.ecs.aws_ecs_service.scaled[0]'
```

Reverse those addresses for true -> false. Generate a fresh reviewed plan afterward;
do not approve service recreation just to change scaling ownership.

## Monitoring, workflow setup and checks

Alarms cover ECS CPU/memory and, only when lb_enabled=true, app target-group 5xx.
There is no shared ALB 5xx alarm. Missing CPU/memory data defaults to breaching;
intentional zero-task services may therefore alarm. TG 5xx defaults to notBreaching
because AWS only publishes nonzero error counts; absence does not imply an outage.
Both missing-data policies are configurable. No dedicated task-count alerts,
Container Insights or SNS subscriptions are configured.

Workflows remain .yml.disabled; follow ../README.md for activation and approval setup.
App selection is inline in the GitHub workflows. Shared Terraform changes select all real apps; app policy/tfvars changes select that
app. app-example is always excluded. Deleted apps require deliberate decommissioning.
Apply uses the approved saved plan, verifies its checksum/age and rejects a newer main
revision. Coordinate application releases with infrastructure applies for the same app.

```bash
cd terraform-infrastructure/terraform
terraform init -backend=false
terraform fmt -check -recursive ..
terraform validate
```

Formatting and validation do not deploy resources. A live plan still needs to verify actual
AWS permissions, resource names, network routes, quotas and optional KMS key policies.
If VS Code shows old module-input errors after CLI validation passes, save files and
use Developer: Reload Window. The correct directory is terraform-infrastructure.

App tfvars only need app-specific inputs. The bootstrap image is defined once in
ecs-service; standard task size, count and health path use shared defaults. Keep the
real application port in tfvars because it configures the SG and target group.
The placeholder listens on that same port, avoiding a networking change on first release.
