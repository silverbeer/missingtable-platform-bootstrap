resource "digitalocean_kubernetes_cluster" "main" {
  name    = "missingtable-dev"
  region  = "nyc1"
  version = "1.32.10-do.1"

  node_pool {
    name       = "default-pool"
    size       = "s-2vcpu-4gb"
    node_count = 2
  }
}

# Namespace
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = "missing-table"
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}

# GHCR Image Pull Secret
resource "kubernetes_secret_v1" "ghcr" {
  metadata {
    name      = "ghcr-secret"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          auth = base64encode("${var.ghcr_username}:${var.ghcr_token}")
        }
      }
    })
  }
}

# Backend Deployment
resource "kubernetes_deployment_v1" "backend" {
  metadata {
    name      = "backend"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels = {
      app = "backend"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        image_pull_secrets {
          name = "ghcr-secret"
        }

        container {
          name  = "backend"
          image = "ghcr.io/silverbeer/missing-table-backend:latest"

          port {
            container_port = 8000
          }

          env {
            name  = "DATABASE_URL"
            value = var.database_url
          }

          env {
            name  = "SUPABASE_URL"
            value = var.supabase_url
          }

          env {
            name  = "SUPABASE_ANON_KEY"
            value = var.supabase_anon_key
          }

          env {
            name  = "SUPABASE_JWT_SECRET"
            value = var.supabase_jwt_secret
          }

          env {
            name  = "ENVIRONMENT"
            value = "development"
          }

          env {
            name  = "DISABLE_SECURITY"
            value = "true"
          }

          env {
            name  = "DISABLE_LOGFIRE"
            value = "true"
          }

          env {
            name  = "CORS_ORIGINS"
            value = "*"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }
}

# Backend Service
resource "kubernetes_service_v1" "backend" {
  metadata {
    name      = "backend-service"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 8000
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

# Frontend Deployment
resource "kubernetes_deployment_v1" "frontend" {
  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels = {
      app = "frontend"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        image_pull_secrets {
          name = "ghcr-secret"
        }

        container {
          name  = "frontend"
          image = "ghcr.io/silverbeer/missing-table-frontend:latest"

          port {
            container_port = 8080
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

# Frontend Service (ClusterIP - exposed via Ingress)
resource "kubernetes_service_v1" "frontend" {
  metadata {
    name      = "frontend-service"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    selector = {
      app = "frontend"
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# =============================================================================
# INGRESS CONTROLLER & ROUTING
# =============================================================================

# Namespace for ingress controller
resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}

# nginx-ingress controller via Helm
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
  version    = "4.9.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  depends_on = [kubernetes_namespace_v1.ingress_nginx]
}

# =============================================================================
# CERT-MANAGER FOR TLS
# =============================================================================

# Namespace for cert-manager
resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}

# cert-manager via Helm
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name
  version    = "1.14.0"

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [kubernetes_namespace_v1.cert_manager]
}

# Wait for cert-manager CRDs to be ready
resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# Let's Encrypt ClusterIssuer
resource "kubectl_manifest" "letsencrypt_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-prod-key
        solvers:
          - http01:
              ingress:
                class: nginx
  YAML

  depends_on = [time_sleep.wait_for_cert_manager]
}

# =============================================================================
# INGRESS WITH TLS
# =============================================================================

# Ingress resource for routing
resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = "missing-table-ingress"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
      "cert-manager.io/cluster-issuer"             = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["missingtable.com"]
      secret_name = "missingtable-tls"
    }

    # Backend API routes: /api/* -> backend-service:8000
    rule {
      host = "missingtable.com"
      http {
        path {
          path      = "/api(/|$)(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = kubernetes_service_v1.backend.metadata[0].name
              port {
                number = 8000
              }
            }
          }
        }

        # Frontend routes: /* -> frontend-service:8080
        path {
          path      = "/()(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = kubernetes_service_v1.frontend.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.ingress_nginx, helm_release.cert_manager]
}

# Data source to get ingress controller LoadBalancer IP
data "kubernetes_service_v1" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
  }

  depends_on = [helm_release.ingress_nginx]
}