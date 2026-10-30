# Existing AWS resources

This module only reads AWS resources; it never creates them.

- cluster_name selects the existing ECS cluster.
- network.vpc_id or network.vpc_name selects the VPC (exactly one).
- All private task subnets are selected by the aws_subnets data source using
  the selected VPC ID and Tier=private tag. There is no manual subnet-ID override. Ensure Tier tags match
  the actual routing of your subnets; a tag alone does not make a subnet private.
- lb_enabled=true looks up load_balancer.existing_name and its existing HTTP
  listener (listener_port defaults to 80). false skips all ALB lookups.

The existing ALB must be in the selected VPC. Its security groups, listener ARN,
DNS name and metric ARN suffix are discovered. If it has multiple SGs, the first
sorted SG identifies the ALB as a source in task ingress. The ALB owner must permit
outbound access to the task port; this module does not modify shared SGs.

Outputs: cluster_name, cluster_arn, vpc_id, task_subnet_ids
and load_balancer (null when lb_enabled=false).
