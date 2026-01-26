provider "linode" {
  # Token from LINODE_TOKEN env var
}

# Extract kubeconfig from LKE cluster
locals {
  kubeconfig = yamldecode(base64decode(linode_lke_cluster.main.kubeconfig))
}

provider "kubernetes" {
  host                   = local.kubeconfig.clusters[0].cluster.server
  token                  = local.kubeconfig.users[0].user.token
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
}

provider "helm" {
  kubernetes {
    host                   = local.kubeconfig.clusters[0].cluster.server
    token                  = local.kubeconfig.users[0].user.token
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
  }
}

provider "kubectl" {
  host                   = local.kubeconfig.clusters[0].cluster.server
  token                  = local.kubeconfig.users[0].user.token
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
  load_config_file       = false
}

# Grafana Cloud provider for dashboard and alerting management
provider "grafana" {
  url  = var.grafana_cloud_stack_url
  auth = var.grafana_cloud_service_account_token
}
