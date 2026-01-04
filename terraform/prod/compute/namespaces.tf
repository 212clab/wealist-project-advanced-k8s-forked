# =============================================================================
# Kubernetes Namespaces
# =============================================================================
# Terraform에서 네임스페이스를 미리 생성하여 라벨 설정
# ArgoCD의 CreateNamespace=true보다 먼저 생성되어 우선 적용됨

# -----------------------------------------------------------------------------
# Kubernetes Provider
# -----------------------------------------------------------------------------
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# -----------------------------------------------------------------------------
# wealist-prod Namespace (Istio Sidecar Injection 활성화)
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "wealist_prod" {
  metadata {
    name = "wealist-prod"

    labels = {
      "istio-injection"          = "enabled"
      "app.kubernetes.io/part-of" = "wealist"
    }
  }

  depends_on = [module.eks]
}
