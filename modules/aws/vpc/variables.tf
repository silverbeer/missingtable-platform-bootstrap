variable "vpc_name" {
  description = "Name prefered for the VPC"
  type        = string
  default     = "missing-table-vpc"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_availability_zones" {
  description = "Availability Zones for the VPC"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "environment" {
  description = "Environment for the VPC"
  type        = string
  default     = "dev"
}

variable "public_subnet_cidr_block" {
  description = "CIDR block for the public subnet"
  type        = map(string)
  default = {
    "us-east-2a" = "10.0.1.0/24"
    "us-east-2b" = "10.0.2.0/24"
  }
}

variable "public_subnet_name" {
  description = "Name for the public subnet"
  type        = string
  default     = "missing-table-public-subnet"
}

variable "private_subnet_cidr_block" {
  description = "CIDR block for the private subnet"
  type        = map(string)
  default = {
    "us-east-2a" = "10.0.10.0/24"
    "us-east-2b" = "10.0.11.0/24"
  }
}

variable "private_subnet_name" {
  description = "Name for the private subnet"
  type        = string
  default     = "missing-table-private-subnet"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}