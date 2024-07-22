output "private_subnets" {
  value = aws_subnet.private
}

output "public_subnets" {
  value = aws_subnet.public
}

output "vpc" {
  value = aws_vpc.cluster_vpc
}

output "private_route_tables" {
  value = aws_route_table.private
}

output "public_route_tables" {
  value = aws_route_table.public
}

output "nat_gateways" {
  value = aws_nat_gateway.nat_gw
}

output "int_gateway" {
  value = aws_internet_gateway.int_gw
}
