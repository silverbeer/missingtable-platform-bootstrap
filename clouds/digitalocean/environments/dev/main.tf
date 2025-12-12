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