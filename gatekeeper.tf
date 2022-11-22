
resource "kubernetes_namespace" "gatekeeper_system" {
  metadata {
    name = "gatekeeper-system"

    labels = {
      "admission.gatekeeper.sh/ignore"  = "no-self-managing"
      control-plane                     = "controller-manager"
      "gatekeeper.sh/system"            = "yes"
      "namespace.statcan.gc.ca/purpose" = "system"
    }
  }
}

module "namespace_gatekeeper_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.gatekeeper_system.id
  namespace_admins = {
    users  = []
    groups = var.administrative_groups
  }

  # CI/CD
  ci_name = var.ci_service_account_name

  # Image Pull Secret
  enable_kubernetes_secret = var.platform_image_repository_credentials_enable
  kubernetes_secret        = local.platform_image_pull_secret_name
  docker_repo              = var.platform_image_repository
  docker_username          = var.platform_image_repository_username
  docker_password          = var.platform_image_repository_password
  docker_email             = var.platform_image_repository_email
  docker_auth              = var.platform_image_repository_auth

  # Dependencies
  dependencies = []
}

module "gatekeeper" {
  source = "git::https://github.com/statcan/terraform-kubernetes-open-policy-agent.git?ref=v4.2.0"

  chart_version = "3.10.0"
  depends_on = [
    kubernetes_namespace.gatekeeper_system
  ]

  helm_repository          = lookup(var.platform_helm_repositories, "gatekeeper", "https://open-policy-agent.github.io/gatekeeper/charts")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  namespace = kubernetes_namespace.gatekeeper_system.id
  image_hub = local.repositories.dockerhub
  image_pull_secrets = [{
    name = local.platform_image_pull_secret_name
  }]

  replicas = var.gk_replicas

  opa_limits_cpu      = var.gk_limits_cpu
  opa_limits_memory   = var.gk_limits_memory
  opa_requests_cpu    = var.gk_requests_cpu
  opa_requests_memory = var.gk_requests_memory

  opa_audit_limits_cpu      = var.gk_audit_limits_cpu
  opa_audit_limits_memory   = var.gk_audit_limits_memory
  opa_audit_requests_cpu    = var.gk_audit_requests_cpu
  opa_audit_requests_memory = var.gk_audit_requests_memory

  values = <<EOF
auditChunkSize: 500
auditMatchKindOnly: true
maxServingThreads: 4

logLevel: WARNING

controllerManager:
  tolerations:
    - key: CriticalAddonsOnly
      operator: Exists
  # exemptNamespaces:
  #   - kube-system

audit:
  tolerations:
    - key: CriticalAddonsOnly
      operator: Exists
EOF
}
