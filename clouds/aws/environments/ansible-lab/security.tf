# =============================================================================
# SECURITY GROUPS - Network-level security rules
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

