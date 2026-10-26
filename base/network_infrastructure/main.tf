data "aws_caller_identity" "current" {}

locals {
  name = "${var.project_prefix}-${var.environment}"
  zones = {
    for index, az in var.availability_zones : az => index
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public" {
  for_each                = local.zones
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-public-${each.key}", Tier = "public" }
}

resource "aws_subnet" "private" {
  for_each                = local.zones
  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 16)
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-private-${each.key}", Tier = "private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-public" }
}
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}
resource "aws_route_table_association" "public" {
  for_each       = local.zones
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

# Each AZ has its own public NAT gateway and Elastic IP.
resource "aws_eip" "nat" {
  for_each = local.zones
  domain   = "vpc"
  tags     = { Name = "${local.name}-nat-${each.key}" }
}
resource "aws_nat_gateway" "main" {
  for_each          = local.zones
  allocation_id     = aws_eip.nat[each.key].id
  subnet_id         = aws_subnet.public[each.key].id
  connectivity_type = "public"
  tags              = { Name = "${local.name}-nat-${each.key}" }
  depends_on        = [aws_internet_gateway.main]
}
resource "aws_route_table" "private" {
  for_each = local.zones
  vpc_id   = aws_vpc.main.id
  tags     = { Name = "${local.name}-private-${each.key}" }
}
resource "aws_route" "private_egress" {
  for_each               = local.zones
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
}
resource "aws_route_table_association" "private" {
  for_each       = local.zones
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}