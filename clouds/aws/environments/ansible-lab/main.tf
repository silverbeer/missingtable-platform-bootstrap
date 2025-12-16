locals {
  common_tags = {
    project     = "ansible-lab"
    environment = "dev"
    managed_by  = "terraform"
    cost_center = "learning"
  }
}

# =============================================================================
# NETWORKING - Simple public-only VPC (no NAT Gateway = $0/month)
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    name = "ansible-lab-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    name = "ansible-lab-igw"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    name = "ansible-lab-public-subnet"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    name = "ansible-lab-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# SECURITY GROUP - SSH + RADIUS ports
# =============================================================================

resource "aws_security_group" "radius_server" {
  name        = "ansible-lab-radius-server"
  description = "Security group for FreeRADIUS learning lab"
  vpc_id      = aws_vpc.main.id

  # SSH access from your IP only
  ingress {
    description = "SSH from allowed IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # RADIUS Authentication (for testing with radtest)
  ingress {
    description = "RADIUS Authentication"
    from_port   = 1812
    to_port     = 1812
    protocol    = "udp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # RADIUS Accounting
  ingress {
    description = "RADIUS Accounting"
    from_port   = 1813
    to_port     = 1813
    protocol    = "udp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Allow all outbound (for package installation)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    name = "ansible-lab-radius-sg"
  })
}

# =============================================================================
# SSH KEY PAIR
# =============================================================================

resource "aws_key_pair" "ansible_lab" {
  key_name   = "ansible-lab-key"
  public_key = var.ssh_public_key

  tags = merge(local.common_tags, {
    name = "ansible-lab-key"
  })
}

# =============================================================================
# EC2 INSTANCE - Ubuntu 24.04 LTS (t3.micro for free tier or ~$8/mo)
# =============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "radius_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.ansible_lab.key_name
  vpc_security_group_ids      = [aws_security_group.radius_server.id]
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.common_tags, {
    name = "radius-server"
    role = "freeradius"
  })
}
