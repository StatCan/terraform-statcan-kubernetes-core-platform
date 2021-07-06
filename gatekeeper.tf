
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
  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-open-policy-agent.git?ref=v3.x"

  depends_on = [
    kubernetes_namespace.gatekeeper_system
  ]

  helm_repository          = lookup(var.platform_helm_repositories, "gatekeeper", "https://open-policy-agent.github.io/gatekeeper/charts")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  chart_version = "3.3.0"

  namespace = kubernetes_namespace.gatekeeper_system.id
  image_hub = local.repositories.dockerhub
  image_pull_secrets = [{
    name = local.platform_image_pull_secret_name
  }]

  values = <<EOF
controllerManager:
  tolerations:
    - key: CriticalAddonsOnly
      operator: Exists

audit:
  tolerations:
    - key: CriticalAddonsOnly
      operator: Exists
EOF
}
