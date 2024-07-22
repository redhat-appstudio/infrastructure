locals {
  len_public_subnets  = max(length(var.public_subnets))
  len_private_subnets = max(length(var.private_subnets))
}

resource "aws_vpc" "cluster_vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags = {
    Name = var.cluster_name
  }
}

data "aws_availability_zones" "az" {
  state = "available"
}

resource "aws_subnet" "private" {
  count             = local.len_private_subnets
  vpc_id            = aws_vpc.cluster_vpc.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.az.names[count.index]

  lifecycle {
    ignore_changes = [tags]
  }
  tags = {
    Name = "private-${split("-", data.aws_availability_zones.az.names[count.index])[2]}"
  }
}

resource "aws_subnet" "public" {
  count             = local.len_public_subnets
  vpc_id            = aws_vpc.cluster_vpc.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = data.aws_availability_zones.az.names[count.index]

  lifecycle {
    ignore_changes = [tags]
  }

  tags = {
    Name = "public-${split("-", data.aws_availability_zones.az.names[count.index])[2]}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "int_gw" {
  vpc_id = aws_vpc.cluster_vpc.id
  tags = {
    Name = var.cluster_name
  }
}

# --> EIP and NAT
resource "aws_eip" "nat_eip" {
  count  = local.len_private_subnets == 0 ? 0 : local.len_public_subnets
  domain = "vpc"
  tags = {
    Name = "eip-${split("-", data.aws_availability_zones.az.names[count.index])[2]}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count         = local.len_private_subnets == 0 ? 0 : local.len_public_subnets
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    "Name" = "nat-gw-${split("-", data.aws_availability_zones.az.names[count.index])[2]}"
  }
}

# --> Private Route Tables
resource "aws_route_table" "private" {
  count  = local.len_private_subnets
  vpc_id = aws_vpc.cluster_vpc.id
  tags = {
    Name = "private-${split("-", data.aws_availability_zones.az.names[count.index])[2]}"
  }
}

resource "aws_route" "private" {
  count                  = var.network_firewall_required == null ? local.len_private_subnets : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
}

resource "aws_route" "private_transit" {
  count                  = var.transit_gateway_id != null ? local.len_private_subnets : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = var.transit_gateway_id
}

resource "aws_route_table_association" "private" {
  count          = local.len_private_subnets
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --> Public Route Tables
resource "aws_route_table" "public" {
  count  = var.network_firewall_required == null ? 1 : 0
  vpc_id = aws_vpc.cluster_vpc.id
  tags = {
    Name = "public"
  }
}

resource "aws_route" "public" {
  count                  = var.network_firewall_required == null ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.int_gw.id
}

resource "aws_route_table_association" "public" {
  count          = var.network_firewall_required == null ? local.len_public_subnets : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attachment" {
  count              = var.transit_gateway_id != null ? 1 : 0
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.cluster_vpc.id
  subnet_ids         = tolist(aws_subnet.private[*].id)

  tags = {
    Name = "Transit Gateway Attachment"
  }
}
