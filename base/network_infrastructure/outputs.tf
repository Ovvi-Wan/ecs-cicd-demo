output "vpc_id" {
  value = aws_vpc.main.id
}
output "public_subnet_ids" {
  value = { for az, subnet in aws_subnet.public : az => subnet.id }
}
output "private_subnet_ids" {
  value = { for az, subnet in aws_subnet.private : az => subnet.id }
}
output "private_route_table_ids" {
  value = { for az, rt in aws_route_table.private : az => rt.id }
}
output "nat_gateway_ids" {
  value = { for az, gateway in aws_nat_gateway.main : az => gateway.id }
}

output "aws_account_id" {
  description = "Effective account from the authenticated AWS provider session."
  value       = data.aws_caller_identity.current.account_id
}
output "aws_caller_arn" {
  description = "Effective user or assumed role executing Terraform."
  value       = data.aws_caller_identity.current.arn
}

output "internet_gateway_id" {
  description = "Internet gateway attached to the VPC."
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "Route table shared by the public subnets."
  value       = aws_route_table.public.id
}

output "public_internet_route" {
  description = "Public default route and its destination/target. The ID is a Terraform provider identifier."
  value = {
    id                     = aws_route.public_internet.id
    route_table_id         = aws_route.public_internet.route_table_id
    destination_cidr_block = aws_route.public_internet.destination_cidr_block
    gateway_id             = aws_route.public_internet.gateway_id
  }
}

output "private_egress_routes" {
  description = "Private default routes, keyed by Availability Zone. IDs are Terraform provider identifiers."
  value = {
    for az, route in aws_route.private_egress : az => {
      id                     = route.id
      route_table_id         = route.route_table_id
      destination_cidr_block = route.destination_cidr_block
      nat_gateway_id         = route.nat_gateway_id
    }
  }
}

output "public_route_table_association_ids" {
  description = "Public subnet route table associations, keyed by Availability Zone."
  value       = { for az, association in aws_route_table_association.public : az => association.id }
}

output "private_route_table_association_ids" {
  description = "Private subnet route table associations, keyed by Availability Zone."
  value       = { for az, association in aws_route_table_association.private : az => association.id }
}

output "nat_eip_allocation_ids" {
  description = "Elastic IP allocation IDs for the NAT gateways, keyed by Availability Zone."
  value       = { for az, eip in aws_eip.nat : az => eip.id }
}

output "nat_public_ips" {
  description = "Public IPv4 addresses used for NAT egress, keyed by Availability Zone."
  value       = { for az, eip in aws_eip.nat : az => eip.public_ip }
}

output "dhcp_options_id" {
  description = "DHCP option set associated automatically by AWS; not created or managed separately by this module."
  value       = aws_vpc.main.dhcp_options_id
}
