variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "missing-table-eks-cluster"
}

variable "cluster_version" {
  description = "Version of the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}