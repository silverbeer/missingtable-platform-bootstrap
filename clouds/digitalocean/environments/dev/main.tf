# =============================================================================
# DOKS CLUSTER
# =============================================================================

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

# =============================================================================
# INGRESS CONTROLLER
# =============================================================================

resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}

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

# Data source to get ingress controller LoadBalancer IP
data "kubernetes_service_v1" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
  }

  depends_on = [helm_release.ingress_nginx]
}

# =============================================================================
# EXTERNAL SECRETS OPERATOR - Sync TLS certs from AWS Secrets Manager
# =============================================================================
resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = kubernetes_namespace_v1.external_secrets.metadata[0].name
  version    = "0.9.11"

  set {
    name  = "provider.aws.region"
    value = "us-east-1"
  }

  set {
    name  = "installCRDs"
    value = true
  }

  depends_on = [kubernetes_namespace_v1.external_secrets]
}

# AWS credentials for External Secrets to read from Secrets Manager
resource "kubernetes_secret_v1" "aws_credentials" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }

  data = {
    access-key-id     = var.aws_access_key_id
    secret-access-key = var.aws_secret_access_key
  }
}

resource "time_sleep" "wait_for_external_secrets" {
  depends_on      = [helm_release.external_secrets]
  create_duration = "30s"
}

# ClusterSecretStore - cluster-wide access to AWS Secrets Manager
resource "kubectl_manifest" "aws_secret_store" {
  yaml_body = <<YAML
      apiVersion: external-secrets.io/v1beta1
      kind: ClusterSecretStore
      metadata:
        name: aws-secrets-manager
      spec:
        provider:
          aws:
            service: SecretsManager            
            region: us-east-2
            auth:
              secretRef:
                accessKeyIDSecretRef:
                  name: aws-credentials
                  namespace: external-secrets
                  key: access-key-id
                secretAccessKeySecretRef:
                  name: aws-credentials
                  namespace: external-secrets
                  key: secret-access-key                
    YAML

  depends_on = [time_sleep.wait_for_external_secrets, kubernetes_secret_v1.aws_credentials]
}

# =============================================================================
# EXTERNAL SECRET - Sync TLS certificate from AWS to K8s
# =============================================================================
resource "kubectl_manifest" "tls_external_secret" {
  yaml_body = <<YAML
      apiVersion: external-secrets.io/v1beta1
      kind: ExternalSecret
      metadata:
        name: missing-table-tls
        namespace: missing-table
      spec:
        refreshInterval: 24h
        secretStoreRef:
          name: aws-secrets-manager
          kind: ClusterSecretStore
        target:
          name: missing-table-tls
          template:
            type: kubernetes.io/tls
            data:
              tls.crt: "{{ .cert }}"
              tls.key: "{{ .key }}"
        data:
          - secretKey: cert
            remoteRef:
              key: missingtable.com-tls
              property: fullchain
          - secretKey: key
            remoteRef:
              key: missingtable.com-tls
              property: private_key
    YAML

  depends_on = [kubectl_manifest.aws_secret_store]
}

# =============================================================================
# EXTERNAL SECRET - Sync Missing Table app secrets (Supabase, database)
# =============================================================================
resource "kubectl_manifest" "missing_table_app_external_secret" {
  yaml_body = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: missing-table-app-secrets
  namespace: missing-table
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: missing-table-secrets
  data:
    - secretKey: database-url
      remoteRef:
        key: missing-table-app-secrets
        property: database_url
    - secretKey: supabase-url
      remoteRef:
        key: missing-table-app-secrets
        property: supabase_url
    - secretKey: supabase-anon-key
      remoteRef:
        key: missing-table-app-secrets
        property: supabase_anon_key
    - secretKey: supabase-service-key
      remoteRef:
        key: missing-table-app-secrets
        property: supabase_service_key
    - secretKey: supabase-jwt-secret
      remoteRef:
        key: missing-table-app-secrets
        property: supabase_jwt_secret
    - secretKey: service-account-secret
      remoteRef:
        key: missing-table-app-secrets
        property: service_account_secret
YAML

  depends_on = [kubectl_manifest.aws_secret_store]
}

# =============================================================================
# EXTERNAL SECRET - GHCR Image Pull Credentials for missing-table
# =============================================================================
resource "kubectl_manifest" "missing_table_ghcr_external_secret" {
  yaml_body = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: missing-table-ghcr
  namespace: missing-table
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: missing-table-ghcr
    template:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: '{"auths":{"ghcr.io":{"username":"silverbeer","password":"{{ .ghcr_pat }}","auth":"{{ printf "silverbeer:%s" .ghcr_pat | b64enc }}"}}}'
  data:
    - secretKey: ghcr_pat
      remoteRef:
        key: missing-table-app-secrets
        property: ghcr_pat
YAML

  depends_on = [kubectl_manifest.aws_secret_store]
}

# =============================================================================
# EXTERNAL SECRET - Sync qualityplaybook.dev TLS certificate
# =============================================================================
resource "kubectl_manifest" "qualityplaybook_tls_external_secret" {
  yaml_body = <<YAML
      apiVersion: external-secrets.io/v1beta1
      kind: ExternalSecret
      metadata:
        name: qualityplaybook-tls
        namespace: qualityplaybook
      spec:
        refreshInterval: 24h
        secretStoreRef:
          name: aws-secrets-manager
          kind: ClusterSecretStore
        target:
          name: qualityplaybook-tls
          template:
            type: kubernetes.io/tls
            data:
              tls.crt: "{{ .cert }}"
              tls.key: "{{ .key }}"
        data:
          - secretKey: cert
            remoteRef:
              key: qualityplaybook.dev-tls
              property: fullchain
          - secretKey: key
            remoteRef:
              key: qualityplaybook.dev-tls
              property: private_key
    YAML

  depends_on = [kubectl_manifest.aws_secret_store]
}

resource "kubernetes_namespace_v1" "qualityplaybook" {
  metadata {
    name = "qualityplaybook"
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}

# =============================================================================
# MONITORING - Grafana Cloud Observability
# =============================================================================

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}

# Sync Grafana Cloud credentials from AWS Secrets Manager
resource "kubectl_manifest" "grafana_cloud_external_secret" {
  yaml_body = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-cloud-credentials
  namespace: monitoring
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: grafana-cloud-credentials
  data:
    - secretKey: prometheus-host
      remoteRef:
        key: grafana-cloud-credentials
        property: prometheus_endpoint
    - secretKey: prometheus-username
      remoteRef:
        key: grafana-cloud-credentials
        property: prometheus_username
    - secretKey: loki-host
      remoteRef:
        key: grafana-cloud-credentials
        property: loki_endpoint
    - secretKey: loki-username
      remoteRef:
        key: grafana-cloud-credentials
        property: loki_username
    - secretKey: access-token
      remoteRef:
        key: grafana-cloud-credentials
        property: access_token
YAML

  depends_on = [
    kubectl_manifest.aws_secret_store,
    kubernetes_namespace_v1.monitoring
  ]
}

# =============================================================================
# GRAFANA KUBERNETES MONITORING
# Deploys: Grafana Alloy, kube-state-metrics, node-exporter
# Sends metrics and logs to Grafana Cloud
# =============================================================================

resource "helm_release" "grafana_k8s_monitoring" {
  name       = "grafana-k8s-monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "k8s-monitoring"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  version    = "2.0.6"

  depends_on = [kubectl_manifest.grafana_cloud_external_secret]

  # Using yamlencode() for type-safe YAML generation
  # Avoids issues like numbers being parsed as scientific notation
  values = [yamlencode({
    cluster = {
      name = "missingtable-dev"
    }

    # Destinations - where to send telemetry
    destinations = [
      {
        name = "prometheus"
        type = "prometheus"
        url  = var.grafana_cloud_prometheus_url
        auth = {
          type     = "basic"
          username = var.grafana_cloud_prometheus_username
          password = var.grafana_cloud_access_token
        }
      },
      {
        name = "loki"
        type = "loki"
        url  = var.grafana_cloud_loki_url
        auth = {
          type     = "basic"
          username = var.grafana_cloud_loki_username
          password = var.grafana_cloud_access_token
        }
      }
    ]

    # Metrics collection
    clusterMetrics = { enabled = true }
    nodeMetrics    = { enabled = true }

    # Log collection - only from our app namespaces
    podLogs = {
      enabled    = true
      namespaces = ["missing-table", "qualityplaybook", "monitoring"]

      # Drop noisy logs to save free tier quota
      extraLogProcessingStages = <<-EOT
        // Drop health check logs
        stage.drop {
          source      = ""
          expression  = ".*GET /health.*"
          drop_counter_reason = "health_check"
        }
        stage.drop {
          source      = ""
          expression  = ".*GET /healthz.*"
          drop_counter_reason = "health_check"
        }
        stage.drop {
          source      = ""
          expression  = ".*GET /ready.*"
          drop_counter_reason = "readiness_probe"
        }
        stage.drop {
          source      = ""
          expression  = ".*GET /livez.*"
          drop_counter_reason = "liveness_probe"
        }
        // Drop debug level logs
        stage.drop {
          source      = ""
          expression  = ".*level=debug.*"
          drop_counter_reason = "debug_logs"
        }
      EOT
    }

    # Cluster events (pod restarts, etc.)
    clusterEvents = { enabled = true }

    # Disable traces for now (defer for later)
    applicationObservability = { enabled = false }

    # Enable Alloy collectors
    alloy-metrics   = { enabled = true }
    alloy-logs      = { enabled = true }
    alloy-singleton = { enabled = true }
  })]
}

# =============================================================================
# ARGOCD - GitOps Continuous Delivery
# =============================================================================

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [digitalocean_kubernetes_cluster.main]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  version    = "7.7.5"

  # Server configuration for ingress
  set {
    name  = "server.insecure"
    value = "true"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  depends_on = [kubernetes_namespace_v1.argocd]
}

# Ingress for ArgoCD UI
resource "kubectl_manifest" "argocd_ingress" {
  yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - argocd.missingtable.com
    secretName: argocd-tls
  rules:
  - host: argocd.missingtable.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
YAML

  depends_on = [helm_release.argocd]
}

# ExternalSecret for ArgoCD TLS certificate
resource "kubectl_manifest" "argocd_tls_external_secret" {
  yaml_body = <<YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-tls
  namespace: argocd
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: argocd-tls
    template:
      type: kubernetes.io/tls
      data:
        tls.crt: "{{ .cert }}"
        tls.key: "{{ .key }}"
  data:
    - secretKey: cert
      remoteRef:
        key: missingtable.com-tls
        property: fullchain
    - secretKey: key
      remoteRef:
        key: missingtable.com-tls
        property: private_key
YAML

  depends_on = [helm_release.argocd, kubectl_manifest.aws_secret_store]
}

# =============================================================================
# ARGOCD APPLICATIONS
# =============================================================================

resource "kubectl_manifest" "argocd_app_missing_table" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: missing-table
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/silverbeer/missing-table
    targetRevision: main
    path: helm/missing-table
  destination:
    server: https://kubernetes.default.svc
    namespace: missing-table
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_app_qualityplaybook" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: qualityplaybook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/silverbeer/qualityplaybook.dev
    targetRevision: main
    path: helm/qualityplaybook
  destination:
    server: https://kubernetes.default.svc
    namespace: qualityplaybook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML

  depends_on = [helm_release.argocd]
}