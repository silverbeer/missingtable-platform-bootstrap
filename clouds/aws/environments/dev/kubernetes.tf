resource "kubernetes_namespace_v1" "missing_table" {
  metadata {
    name = "missing-table"
  }
}
