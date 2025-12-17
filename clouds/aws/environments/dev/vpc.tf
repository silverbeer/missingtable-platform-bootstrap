module "vpc" {
  source                 = "../../../../modules/aws/vpc"
  vpc_name               = "missing-table-vpc"
  vpc_cidr_block         = "10.0.0.0/16"
  vpc_availability_zones = ["us-east-2a", "us-east-2b"]
  environment            = "dev"
  tags                   = local.common_tags

  # Subnet configuration (keyed by availability zone)
  public_subnet_cidr_block = {
    "us-east-2a" = "10.0.1.0/24"
    "us-east-2b" = "10.0.2.0/24"
  }
  private_subnet_cidr_block = {
    "us-east-2a" = "10.0.10.0/24"
    "us-east-2b" = "10.0.11.0/24"
  }
}
