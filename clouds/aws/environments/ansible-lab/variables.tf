variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH (your IP)"
  type        = string
}
