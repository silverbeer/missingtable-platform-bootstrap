variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "runner_enabled" {
  description = "Set to false to destroy the EC2 runner (saves ~$15/mo)"
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH. Find your IP with: curl -s ifconfig.me, then use <your-ip>/32 (e.g., 1.2.3.4/32)"
  type        = string
}

variable "runner_ssh_public_key" {
  description = "SSH public key for runner access"
  type        = string
}