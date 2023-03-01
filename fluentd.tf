
resource "kubernetes_namespace" "fluentd_system" {
  metadata {
    name = "fluentd-system"

    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
    }
  }
}

module "namespace_fluentd_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.fluentd_system.id
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

  # Fluentd config
  fluentd_config = var.global_fluentd_config
}

module "fluentd" {
  source = "git::https://github.com/statcan/terraform-kubernetes-fluentd.git?ref=v3.0.1"

  depends_on = [
    kubernetes_namespace.fluentd_system
  ]

  helm_repository          = lookup(var.platform_helm_repositories, "fluentd-operator", "https://statcan.github.io/charts")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  chart_version = "0.5.1"

  helm_namespace = kubernetes_namespace.fluentd_system.id

  values = <<EOF
image:
  repository: vmware/kube-fluentd-operator
  tag: v1.16.5

fluentd:
  resources:
    limits:
      memory: 8Gi
    requests:
      memory: 1Gi

nodeSelector:
  kubernetes.io/os: linux

tolerations:
- effect: NoSchedule
  operator: Exists
- effect: NoExecute
  operator: Exists

rbac:
  create: yes
EOF
}
