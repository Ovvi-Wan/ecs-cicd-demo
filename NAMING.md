# AWS resource naming convention

Use lowercase, hyphen-separated project, environment, and application identifiers.
Application resources use `<project>-<environment>-<application>` (called `app`
below). Shared environment resources use `<project>-<environment>` (`shared`).
Add a purpose suffix when several resources of the same kind belong to one app.
Do not put credentials, personal data, release numbers, or mutable image tags in names.

This is the repository convention, not an AWS-mandated universal format. Keep the
existing 46-character limit on `app`; individual services have their own limits.

| Resource | Convention |
| --- | --- |
| Secrets Manager | `<project>/<environment>/<application>/secrets` |
| ECR repository | `app` |
| ECS service and task-definition family | `app` |
| ECS container | `app` literal by default; keep stable across deployments |
| Task execution role / task role | `app-execution` / `app-task` |
| Managed task policy | `app-<policy-file-stem>` |
| Inline IAM policy | Purpose within its owning role, e.g. `task-startup` |
| ECS log group | `/ecs/app` |
| Task security group | `app-task-<generated suffix>`, Name tag `app-task-sg` |
| Target group | Generated `app-` prefix, Name tag `<project>-<environment>-<application>-tg` |
| Listener rules and security-group rules | Provider IDs; use descriptive Terraform map keys |
| Scaling policy | `app-cpu` / `app-memory` |
| CloudWatch alarm | `app-cpu`, `app-memory`, `app-target-5xx` |
| SNS alarm topic | `app-alarms` |
| Shared ECS cluster / VPC Name tag | `shared` |
| Internet gateway Name tag | `shared-igw` |
| Subnet / route-table Name tag | `shared-<public-or-private>-<availability-zone>`; shared public route table uses `shared-public` |
| NAT gateway / EIP Name tag | `shared-nat-<availability-zone>` |
| CodeBuild project | `<project>-<runner-purpose>` |
| CodeBuild role / logs | `<project>-<runner-purpose>-runner` / `/aws/codebuild/<project>-<runner-purpose>` |
| Terraform state bucket | `<project>-tfstate-<account-id>-<region>` |
| Attachments, routes, associations, and configuration resources | Inherit the parent identity; do not invent a separate physical name |

The target group's generated physical name allows create-before-destroy within
its short name limit. Use the Name tag and standard tags to identify its app.
Security groups also retain generated suffixes for replacement. Resources without
a configurable physical name should use tags where supported and meaningful
Terraform labels. Terraform labels use snake_case; they are separate from AWS names.

Application resources inherit `Project`, `Environment`, `Application`, and
`ManagedBy=Terraform` tags. Apply the same tags to future shared resources, omitting
`Application` when no single app owns them. Account and region belong in globally
unique names such as S3 buckets; include them elsewhere only if the resource scope
requires disambiguation. Runner projects and state storage are shared across apps.

## Secret overrides and existing deployments

The default billing secret is `ecs-cicd-tutorial/dev/billing/secrets`. The final
segment is `secrets` for the application's secret bundle. Secrets use the
default AWS-managed `aws/secretsmanager` key.
Prefer full ARNs from Terraform outputs for consumers.
Avoid names ending in a hyphen plus six characters because they can be confused
with the suffix AWS adds to secret ARNs ([AWS guidance](https://docs.aws.amazon.com/secretsmanager/latest/userguide/troubleshoot.html)).

`secret.name` remains an explicit compatibility escape hatch, with AWS character
and length validation. For example, set
`secret = { name = "ecs-cicd-tutorial-dev-billing" }` to preserve a deployed legacy
secret. A name change replaces the secret and does not migrate values. Before
applying a migration, arrange secure value transfer and update consumers to the
new ARN; retain the old secret until consumers have switched. Never commit values.

Other existing physical names remain unchanged by this convention. Review plans
for replacements when changing any identifier. The workflow templates currently
use one backend key per app (`infrastructure/<application>/terraform.tfstate`);
introducing multiple environments for the same app also requires separate state
keys and concurrency groups, not just a new environment in a resource name.

## Adding resources

Derive names from the root identity passed to modules instead of duplicating
project/environment/application strings. Select a purpose from the table, check
the resource's naming limits, and document any exception here. Keep names stable
across releases and reference resource outputs rather than reconstructing ARNs.
