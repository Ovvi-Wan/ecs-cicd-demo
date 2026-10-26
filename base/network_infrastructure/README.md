# Network infrastructure

Run this standalone root from base/network_infrastructure on an approved bootstrap
runner. The app workflows do not deploy it. No workstation Terraform setup is required.
Creates a dev VPC, two public subnets, two private subnets, an internet gateway, route tables and associations, two Elastic IPs and two public zonal NAT gateways, one per AZ.
No ECS, ALB or application security groups are created yet.

```powershell
# Review your existing terraform.tfvars (AZs, region, prefix and CIDR).
# Fill in terraform.tfvars; set the backend bucket in versions.tf and review CIDR/AZs.
terraform init
terraform plan -out=network.tfplan
terraform apply network.tfplan
terraform output
```

Public routes use the internet gateway. Each private route uses the NAT gateway in the same AZ.
No subnet automatically assigns public IPs. Future internet-facing ALBs can use the public subnets.
NAT gateways and public IPv4 addresses incur charges when deployed. Cross-AZ traffic may incur additional charges.
Each AZ has an independent NAT egress path.
Keep AZ order stable because it determines subnet CIDRs.
The /16 input is divided into non-overlapping /24s. Confirm it does not overlap your other networks.
AWS must make the configured AZs available in your account. This checkout does not include mocked tests.

Terraform version, provider requirements, backend declaration and AWS provider configuration are all in versions.tf. All backend values are inline in versions.tf. Replace the bucket placeholder before initialization.

See [architecture.md](architecture.md) for the resource diagram, CIDR explanation and dynamic account identity. The AWS account comes from your active credentials; no aws_account_id input is needed. Check aws sts get-caller-identity before applying.

The nat_gateway_ids output is a map keyed by AZ. Moved blocks preserve the original us-east-1a NAT and Elastic IP if the old configuration was deployed. Review a fresh plan; do not reuse an older saved plan.
