module "eks" {
  source             = "../../../../modules/aws/eks"
  cluster_name       = "missing-table-eks-cluster-dev"
  cluster_version    = "1.31"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = values(module.vpc.public_subnet_ids)
  private_subnet_ids = values(module.vpc.private_subnet_ids)
  tags               = local.common_tags

  # Node configuration (t4g.small free tier until Dec 2025)
  instance_types    = ["t4g.small"]
  architecture      = "arm64"
  node_desired_size = 2
  node_min_size     = 1
  node_max_size     = 3
}
