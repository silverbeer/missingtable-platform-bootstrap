output "vpc_id" {
    value = aws_vpc.main.id
}

output "vpc_cidr_block" {
    value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
    value = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
    value = { for k, v in aws_subnet.private : k => v.id }
}

output "private_subnet_tags" {
    value = { for k, v in aws_subnet.private : k => v.tags }
}

output "internet_gateway_id" {
    value = aws_internet_gateway.main.id
}

output "public_route_table_id" {
    value = aws_route_table.public.id
}

output "public_route_table_associations" {
    value = { for k, v in aws_route_table_association.public : k => v.id }
}