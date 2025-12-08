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

output "backend_service" {
    description = "The internal backend service endpoint"
    value = "${kubernetes_service_v1.backend.metadata[0].name}:8000"
}

output "namespace" {
    description = "The namespace of the application"
    value = kubernetes_namespace_v1.app.metadata[0].name
}

output "backend_deployment" {
    description = "The deployment of the backend service"
    value = kubernetes_deployment_v1.backend.metadata[0].name
}

output "frontend_deployment" {
    description = "The deployment of the frontend service"
    value = kubernetes_deployment_v1.frontend.metadata[0].name
}