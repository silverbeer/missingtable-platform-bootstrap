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