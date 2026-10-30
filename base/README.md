# Base infrastructure

Four standalone Terraform roots in the monorepo. They are not child modules of
application infrastructure, and the app workflows do not apply them.

| Root | Responsibility | Existing backend key |
| --- | --- | --- |
| s3_state_bucket | State bucket and access/encryption/versioning policies | base/s3_state_bucket/terraform.tfstate |
| codebuild_projects | Runner projects, IAM policies, logs and webhooks | base/codebuild_projects/terraform.tfstate |
| network_infrastructure | VPC, subnets and one NAT gateway per AZ | base/network_infrastructure/dev/terraform.tfstate |

## Bootstrap order

Use an approved bootstrap execution environment with AWS credentials independent
of the runner projects being provisioned. No workstation Terraform setup is required.
Verify/create the bucket first; CodeBuild and network roots can follow independently.
Review saved plans before apply. The current versions.tf files have ACTIVE S3
backends. For a brand-new account without the bucket, follow the state-bucket
README bootstrap procedure first. A runner cannot create itself before it exists.

Keep existing bucket/state keys for already deployed resources. A folder move does
not migrate state. Do not create empty states to recreate resources already owned
by another state. The network's dev setting is retained; app pipelines have one
configuration per app.

For the monorepo, authorize CodeConnections for Ovvi-Wan/ecs-cicd-demo and update
old runner repository mappings before activating CI. The infrastructure repository mapping is updated in source; no Terraform apply is performed.

Read [state bucket](s3_state_bucket/README.md), [CodeBuild](codebuild_projects/README.md),
[network](network_infrastructure/README.md), and [root setup](../README.md).
Keep state, saved plans, caches and credentials out of Git.

## Shared ECS cluster

[ecs_cluster](ecs_cluster/README.md) is a fourth optional foundation root. Its state
key is base/ecs_cluster/dev/terraform.tfstate. Create once if no suitable shared
cluster exists, before deploying apps. Container Insights is disabled. App jobs
use a cluster data source and never create this shared resource. The infrastructure
CodeBuild repository mapping is now updated to the monorepo in source; applying
that base change and authorizing CodeConnections are separate bootstrap steps.
