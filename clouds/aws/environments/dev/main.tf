locals {
  common_tags = {
    project     = "missing-table"
    environment = "dev"
    managed_by  = "terraform"
    cost_center = "engineering"
  }
}

resource "kubernetes_namespace_v1" "missing_table" {
  metadata {
    name = "missing-table"
  }
}

module "vpc" {
  source                 = "../../../../modules/aws/vpc"
  vpc_name               = "missing-table-vpc"
  vpc_cidr_block         = "10.0.0.0/16"
  vpc_availability_zones = ["us-east-2a", "us-east-2b"]
  environment            = "dev"
  tags                   = local.common_tags
}

module "eks" {
  source             = "../../../../modules/aws/eks"
  cluster_name       = "missing-table-eks-cluster-dev"
  cluster_version    = "1.31"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = values(module.vpc.public_subnet_ids)
  private_subnet_ids = values(module.vpc.private_subnet_ids)
  tags               = local.common_tags
}

resource "kubernetes_deployment_v1" "nginx_test" {
  metadata {
    name      = "nginx-test"
    namespace = kubernetes_namespace_v1.missing_table.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx-test"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-test"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "nginx_test" {
  metadata {
    name      = "nginx-test"
    namespace = kubernetes_namespace_v1.missing_table.metadata[0].name
  }

  spec {
    selector = {
      app = "nginx-test"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}



