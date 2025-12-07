resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = var.vpc_name
    }
}

resource "aws_subnet" "public" {
    for_each = var.public_subnet_cidr_block
    vpc_id = aws_vpc.main.id
    cidr_block = each.value
    availability_zone = each.key
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.public_subnet_name}-${each.key}"
    }
}

resource "aws_subnet" "private" {
    for_each = var.private_subnet_cidr_block
    vpc_id = aws_vpc.main.id
    cidr_block = each.value
    availability_zone = each.key
    map_public_ip_on_launch = false
    tags = {
        Name = "${var.private_subnet_name}-${each.key}"
    }
}

resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "${var.vpc_name}-internet-gateway"
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }
    tags = {
        Name = "${var.vpc_name}-public-route-table"
    }
}

resource "aws_route_table_association" "public" {
    for_each = aws_subnet.public
    subnet_id = each.value.id
    route_table_id = aws_route_table.public.id
}

resource aws_eip "nat" {
    domain = "vpc"

    tags = {
        Name = "${var.vpc_name}-nat-eip"
    }
}

resource "aws_nat_gateway" "main" {
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public["us-east-2a"].id
    tags = {
        Name = "${var.vpc_name}-nat-gateway"
    }
    depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.main.id
    }
    tags = {
        Name = "${var.vpc_name}-private-route-table"
    }
}

resource "aws_route_table_association" "private" {
    for_each = aws_subnet.private
    subnet_id = each.value.id
    route_table_id = aws_route_table.private.id
}