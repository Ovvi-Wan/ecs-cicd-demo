# Runner permissions

permissions.tf defines two separate workload policies. Each project already has
its own IAM role and its own baseline CloudWatch Logs/CodeConnections policy.

| Project map key | Workload policy | Access |
| --- | --- | --- |
| application | image_build | Full private ECR administration, including authentication, push/pull, image tags, deletion, repository policies, lifecycle policies, scans and registry settings. |
| infrastructure | infrastructure | ECS, load balancing, ECR, VPC networking, CloudWatch Logs, metric alarms, Secrets Manager, Application Auto Scaling, project IAM roles/policies and Terraform state. |

Attachments use the stable map keys, not a repository-name comparison.
Changing a repository URL does not change its project's permission category.
Both infrastructure and application entries must exist in runner_projects.

## Scope

ECR permissions apply to any repository accessible through this policy, with no
repository-name or region restriction. This includes destructive operations.
Cross-account access still requires the target account's authorization.

Infrastructure service permissions are broad within the account. IAM role and
customer-managed policy names must start with the configured project_prefix,
using the default IAM path (/). PassRole is restricted to ECS tasks.
ECS, ELB and ECS Application Auto Scaling may create their service-linked roles.

This is a privileged tutorial deployment role, not a permissions boundary:
it can author arbitrary policies for matching roles, including the runner roles.
Only trusted workflows should run on the infrastructure runner.

EC2 access covers the current VPC, subnets, route tables/routes, internet
gateways, NAT gateways, Elastic IPs and security groups, plus EC2 describe calls.
It does not grant general EC2 instance administration.

State bucket access uses the existing naming convention:
PROJECT_PREFIX-tfstate-ACCOUNT_ID-REGION.
It permits listing, reading/writing objects and deleting .tflock lock objects.
It does not manage the bucket itself or delete state files.
Update the local value if the state bucket is renamed.
The S3 backend bucket setting in versions.tf must also be set separately.

## Not added yet

- S3 artifact storage: choose a dedicated bucket/prefix before granting access.
- Application deployment from the image builder: ECS deployment and PassRole
  permissions are currently only on the infrastructure runner.
- HTTPS certificates and DNS: ACM and Route 53 permissions when those are added.
- Customer-managed encryption keys: KMS permissions and key policies if needed.
- Cloud Map / Service Connect discovery resources, VPC endpoints, custom network
  ACLs, DHCP options and other network extensions: add when used.
- Enhanced scanning administration: ECR permissions cover ECR-side scan settings
  and results; Amazon Inspector administration is separate. StartImageScan is
  for basic scanning.
- CodeBuild/CodeConnections administration: maintain the base runner setup using
  your local administrator session for now.

Terraform validation checks configuration structure, not effective AWS
authorization. Organization policies, permission boundaries and resource policies
may further restrict these permissions. No AWS resources were changed.
