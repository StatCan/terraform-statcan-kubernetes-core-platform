
resource "kubernetes_namespace" "aad_pod_identity_system" {
  metadata {
    name = "aad-pod-identity-system"

    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
    }
  }
}

module "namespace_aad_pod_identity_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.aad_pod_identity_system.id
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

module "aad_pod_identity" {
  providers = {
    helm = helm
  }

  source = "git::https://github.com/statcan/terraform-kubernetes-aad-pod-identity.git?ref=v3.x"

  depends_on = [
    kubernetes_namespace.aad_pod_identity_system
  ]

  helm_namespace           = kubernetes_namespace.aad_pod_identity_system.id
  helm_repository          = lookup(var.platform_helm_repositories, "aad-pod-identity", "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  values = <<EOF
forceNamespaced: "true"

image:
  repository: ${local.repositories.mcr}oss/azure/aad-pod-identity

imagePullSecrets:
  - name: ${local.platform_image_pull_secret_name}

rbac:
  enabled: true
  # NMI requires permissions to get secrets when service principal (type: 1) is used in AzureIdentity.
  # If using only MSI (type: 0) in AzureIdentity, secret get permission can be disabled by setting this to false.
  allowAccessToSecrets: false

mic:
  tolerations:
    - key: CriticalAddonsOnly
      operator: Exists

nmi:
  tolerations:
    - effect: NoSchedule
      operator: Exists
EOF
}
