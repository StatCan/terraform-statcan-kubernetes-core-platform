resource "kubernetes_namespace" "vault_agent_system" {
  metadata {
    name = "vault-agent-system"

    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
    }
  }
}

module "namespace_vault_agent_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.vault_agent_system.id
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

module "vault_agent" {
  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-vault-agent.git?ref=main"

  depends_on = []

  helm_release_name        = "vault-agent"
  helm_namespace           = kubernetes_namespace.vault_agent_system.id
  helm_repository          = lookup(var.platform_helm_repositories, "vault", "https://helm.releases.hashicorp.com")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  values = <<EOF
injector:
  image:
    repository: "${local.repositories.dockerhub}hashicorp/vault-k8s"
    tag: "0.10.1"

  externalVaultAddr: ${var.vault_address}
  authPath: auth/${var.cluster_name}
EOF
}

resource "kubernetes_service_account" "vault_auth" {
  metadata {
    name      = "vault-auth"
    namespace = kubernetes_namespace.vault_agent_system.metadata.0.name
  }
}

resource "kubernetes_cluster_role_binding" "vault_auth_token_review" {
  metadata {
    name = "role-tokenreview-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_auth.metadata.0.name
    namespace = kubernetes_service_account.vault_auth.metadata.0.namespace
  }
}
