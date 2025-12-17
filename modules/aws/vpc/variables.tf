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
}

variable "environment" {
  description = "Environment for the VPC"
  type        = string
  default     = "dev"
}

variable "public_subnet_cidr_block" {
  description = "CIDR blocks for public subnets, keyed by availability zone"
  type        = map(string)
}

variable "public_subnet_name" {
  description = "Name for the public subnet"
  type        = string
  default     = "missing-table-public-subnet"
}

variable "private_subnet_cidr_block" {
  description = "CIDR blocks for private subnets, keyed by availability zone"
  type        = map(string)
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