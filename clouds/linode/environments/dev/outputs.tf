output "cluster_id" {
  description = "The LKE cluster ID"
  value       = linode_lke_cluster.main.id
}

output "cluster_endpoint" {
  description = "The LKE cluster API endpoint"
  value       = local.kubeconfig.clusters[0].cluster.server
  sensitive   = true
}

output "kubeconfig" {
  description = "Raw kubeconfig for kubectl access"
  value       = base64decode(linode_lke_cluster.main.kubeconfig)
  sensitive   = true
}

output "app_url" {
  description = "The URL of the application (via ingress)"
  value       = "https://missingtable.com"
}

output "ingress_ip" {
  description = "Ingress LoadBalancer IP (point DNS here)"
  value       = data.kubernetes_service_v1.ingress_nginx.status[0].load_balancer[0].ingress[0].ip
}
