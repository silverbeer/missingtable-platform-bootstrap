output "cluster_id" {
    value = digitalocean_kubernetes_cluster.main.id
}

output "cluster_endpoint" {
    value = digitalocean_kubernetes_cluster.main.endpoint
}

output "kubeconfig" {
    value     = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
    sensitive = true
}

output "app_url" {
    description = "The URL of the application (via ingress)"
    value = "https://missingtable.com"
}

output "ingress_ip" {
    description = "Ingress LoadBalancer IP (point DNS here)"
    value = data.kubernetes_service_v1.ingress_nginx.status[0].load_balancer[0].ingress[0].ip
}