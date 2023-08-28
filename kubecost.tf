resource "kubernetes_namespace" "kubecost_system" {
  metadata {
    name = "kubecost-system"

    labels = {
      "istio-injection"                                = "enabled"
      "namespace.statcan.gc.ca/purpose"                = "system"
      "network.statcan.gc.ca/allow-ingress-controller" = "true"
    }
  }
}

module "namespace_kubecost_system" {
  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.kubecost_system.id
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
module "kubecost" {
  providers = {
    helm = helm
  }

  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-kubecost.git?ref=v4.0.0"

  depends_on = [
    kubernetes_namespace.kubecost_system
  ]

  namespace = kubernetes_namespace.kubecost_system.metadata.0.name

  helm_repository = {
    name     = lookup(var.platform_helm_repositories, "cost-analyzer", "https://kubecost.github.io/cost-analyzer")
    username = var.platform_helm_repository_username
    password = var.platform_helm_repository_password
  }

  hubs = {
    gcr       = local.repositories.gcr
    dockerhub = local.repositories.dockerhub
  }

  image_pull_secret_names = [local.platform_image_pull_secret_name]

  ingress = {
    enabled = false
  }

  prometheus = {
    fqdn = "http://kube-prometheus-stack-prometheus.prometheus-system.svc:9090"
    service_monitor = {
      cost_analyzer = {
        metric_relabelings = var.kubecost.metric_relabelings
      }
    }
  }

  grafana = {
    domain_name = "kube-prometheus-stack-grafana.prometheus-system"
  }

  notifications = {
    global_slack_webhook_url = var.kubecost.notifications.global_slack_webhook_url
    alerts                   = var.kubecost.notifications.alerts
  }

  tolerations = [{
    key      = "CriticalAddonsOnly"
    operator = "Exists"
  }]

  product_configs = {
    azure = {
      subscription_id  = var.subscription_id
      client_id        = var.kubecost.azure.client_id
      client_password  = var.kubecost.azure.client_password
      tenant_id        = var.tenant_id
      offer_durable_id = "MS-AZR-0017P" # Can be pulled from the Subscription
    }
    cluster_name                = var.cluster_name
    cluster_profile             = var.kubecost.cluster_profile
    grafana_url                 = "https://grafana.${var.ingress_domain}"
    token                       = var.kubecost.token
    product_key                 = var.kubecost.product_key
    extra_label_mapping_configs = { "product_external_label" = "wid" }
    shared_namespaces           = var.kubecost.shared_namespaces
  }
}
