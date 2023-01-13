
resource "kubernetes_namespace" "cert_manager_system" {
  metadata {
    name = "cert-manager-system"

    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
    }
  }
}

module "namespace_cert_manager_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.cert_manager_system.id
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

module "cert_manager_identity" {
  source = "git::https://github.com/statcan/terraform-kubernetes-aad-pod-identity-template.git?ref=v2.x"

  depends_on = [
    module.aad_pod_identity
  ]

  identity_name = "cert-manager"
  namespace     = kubernetes_namespace.cert_manager_system.id

  type        = 0
  client_id   = var.cert_manager_identity_client_id
  resource_id = var.cert_manager_identity_id
}

module "cert_manager" {
  source = "git::https://github.com/statcan/terraform-kubernetes-cert-manager.git?ref=v3.x"

  chart_version = "1.11.0"

  depends_on = [
    module.cert_manager_identity
  ]

  helm_namespace           = kubernetes_namespace.cert_manager_system.id
  helm_repository          = lookup(var.platform_helm_repositories, "cert-manager", "https://charts.jetstack.io")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  values = <<EOF
global:
  imagePullSecrets:
    - name: "${local.platform_image_pull_secret_name}"

tolerations:
  - key: CriticalAddonsOnly
    operator: Exists

podLabels:
  aadpodidbinding: cert-manager

image:
  repository: ${local.repositories.quay}jetstack/cert-manager-controller

webhook:
  image:
    repository: ${local.repositories.quay}jetstack/cert-manager-webhook

  tolerations:
    - key: CriticalAddonsOnly
      operator: Exists

cainjector:
  image:
    repository: ${local.repositories.quay}jetstack/cert-manager-cainjector

  tolerations:
    - key: CriticalAddonsOnly
      operator: Exists

podDnsConfig:
  nameservers:
    # Use external DNS provider to verify DNS records have propagated
    # (https://www.cira.ca/cybersecurity-services/canadian-shield)
    - 149.112.121.10
    - 149.112.122.10

# Enable metrics scraping
prometheus:
  enabled: true
  servicemonitor:
    enabled: true
    # prometheusInstance: default
    # interval: 60s
    # scrapeTimeout: 30s
    # labels: {}
    # honorLabels: false
EOF
}

module "cert_manager_letsencrypt_staging" {
  source = "git::https://github.com/statcan/terraform-kubernetes-cert-manager-issuer.git?ref=v1.2.0"

  depends_on = [
    module.cert_manager
  ]

  name                                    = "letsencrypt-staging"
  namespace                               = kubernetes_namespace.cert_manager_system.id
  acme_email                              = "statcan.cwmd-csep-cns-dimct-pasi-sin.statcan@statcan.gc.ca"
  acme_dns01_azuredns_subscription_id     = var.cert_manager_subscription_id
  acme_dns01_azuredns_resource_group_name = var.cert_manager_resource_group_name
  acme_dns01_azuredns_hosted_zone_name    = var.cert_manager_hosted_zone_name
  acme_http01_ingress_class               = "external"
  acme_http01_ingress_service_type        = "ClusterIP"
  acme_server                             = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

module "cert_manager_letsencrypt" {
  source = "git::https://github.com/statcan/terraform-kubernetes-cert-manager-issuer.git?ref=v1.2.0"

  depends_on = [
    module.cert_manager
  ]

  name                                    = "letsencrypt"
  namespace                               = kubernetes_namespace.cert_manager_system.id
  acme_email                              = "statcan.cwmd-csep-cns-dimct-pasi-sin.statcan@statcan.gc.ca"
  acme_dns01_azuredns_subscription_id     = var.cert_manager_subscription_id
  acme_dns01_azuredns_resource_group_name = var.cert_manager_resource_group_name
  acme_dns01_azuredns_hosted_zone_name    = var.cert_manager_hosted_zone_name
  acme_http01_ingress_class               = "external"
  acme_http01_ingress_service_type        = "ClusterIP"
  acme_server                             = "https://acme-v02.api.letsencrypt.org/directory"
}
