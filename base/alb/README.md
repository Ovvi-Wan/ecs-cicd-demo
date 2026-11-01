# Shared application load balancer

Standalone Terraform root, applied separately from application workflows. Requires
the state bucket and an existing VPC from `base/network_infrastructure`. Discovers
the VPC by Name and its public subnets by `Tier=public`; requires at least two AZs
and one selected subnet per AZ. Those subnets must have internet-gateway routes.

Creates an internet-facing IPv4 ALB, one security group, and an HTTP listener on
port 80. Unmatched requests return 404. Apps own target groups and listener rules;
this root creates no ECS service, cluster, or application deployment.

The default name is `ecs-cicd-tutorial-dev-alb`. State is isolated at
`base/alb/dev/terraform.tfstate`. For another environment, explicitly configure a
different backend key as well as inputs; changing environment alone does not move state.

Review `terraform.tfvars`: HTTP ingress defaults to all IPv4 clients. Egress is
limited to TCP ports 3000 and 8080 within the VPC's primary CIDR. Add any other task
or health-check port before onboarding that app. App Terraform allows ingress
from this ALB security group. This test endpoint uses unencrypted HTTP; it has no
certificate or HTTPS listener. ALB usage incurs AWS charges.

From this directory:

```powershell
aws sts get-caller-identity
terraform init
terraform validate
terraform plan -out=alb.tfplan
# Review the saved plan and obtain approval before this command:
terraform apply alb.tfplan
terraform output
```

After the ALB is approved and deployed, configure only the selected application:

```hcl
lb_enabled = true
load_balancer = {
  existing_name = "ecs-cicd-tutorial-dev-alb"
  listener_port = 80
  rules = {
    app = { priority = 200, path_patterns = ["/orders", "/orders/*"] }
  }
}
```

Use a unique listener-rule priority for each app. Routing preserves the request
path; it does not strip `/orders`. The default health check `/health` goes directly
to the target port, independently of listener path matching. A 404 at the ALB root
is expected. A successful placeholder response at `/orders/` proves bootstrap
routing only, not deployment of the real application.

Destroy application routing resources before removing this shared ALB. If deletion
protection is enabled, disable it through a reviewed apply before destroying.
