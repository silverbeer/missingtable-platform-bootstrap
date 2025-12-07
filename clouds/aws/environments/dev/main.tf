terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

module "vpc" {
  source = "../../../../modules/aws/vpc"
  vpc_name = "missing-table-vpc"
  vpc_cidr_block = "10.0.0.0/16"
  vpc_availability_zones = ["us-east-2a", "us-east-2b"]
  environment = "dev"
}

module "eks" {
  source = "../../../../modules/aws/eks"
  cluster_name = "missing-table-eks-cluster-dev"
  cluster_version = "1.31"
  vpc_id = module.vpc.vpc_id
  public_subnet_ids = values(module.vpc.public_subnet_ids)
  private_subnet_ids = values(module.vpc.private_subnet_ids)
}