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
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

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

  source = "git::https://github.com/statcan/terraform-kubernetes-kubecost.git?ref=v3.1.0"

  chart_version = "1.92.0"
  depends_on = [
    kubernetes_namespace.kubecost_system
  ]

  helm_namespace           = kubernetes_namespace.kubecost_system.id
  helm_repository          = lookup(var.platform_helm_repositories, "cost-analyzer", "https://kubecost.github.io/cost-analyzer")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  values = <<EOF
global:
  prometheus:
    enabled: false
    fqdn: http://kube-prometheus-stack-prometheus.prometheus-system.svc:9090
  grafana:
    enabled: false
    domainName: kube-prometheus-stack-grafana.prometheus-system
    proxy: false

kubecostToken: "${var.kubecost_token}"
imagePullSecrets:
  - name: "${local.platform_image_pull_secret_name}"
kubecostFrontend:
  image: "${local.repositories.gcr}kubecost1/frontend"
kubecost:
  image: "${local.repositories.gcr}kubecost1/server"
kubecostModel:
  image: "${local.repositories.gcr}kubecost1/cost-model"
remoteWrite:
  postgres:
    initImage: "${local.repositories.gcr}kubecost1/sql-init"
networkCosts:
  image: "${local.repositories.gcr}kubecost1/kubecost-network-costs:v16.0"
clusterController:
  image: "${local.repositories.gcr}kubecost1/cluster-controller:v0.1.0"
initChownDataImage: "${local.repositories.dockerhub}busybox"
ingress:
  enabled: true
  hosts:
  - "kubecost.${var.ingress_domain}"
  paths:
  - /
  pathType: Prefix
tolerations:
  - key: CriticalAddonsOnly
    operator: Exists
grafana:
  sidecar:
    dashboards:
      enabled: true
    datasources:
      enabled: false

kubecostProductConfigs:
  clusterName: "${var.cluster_name}"
  clusterProfile: ${var.kubecost_cluster_profile}
  currencyCode: "CAD"
  azureBillingRegion: CA
  azureSubscriptionID: ${var.subscription_id}
  azureClientID: ${var.kubecost_client_id}
  azureClientPassword: ${var.kubecost_client_secret}
  azureOfferDurableID: MS-AZR-0017P
  azureTenantID: ${var.tenant_id}
  createServiceKeySecret: true
  grafanaURL: https://grafana.${var.ingress_domain}
  productKey:
    enabled: true
    key: ${var.kubecost_product_key}
  labelMappingConfigs:
    enabled: true
    owner_label: "project.statcan.gc.ca/lead"
    team_label: "project.statcan.gc.ca/team"
    department_label: "project.statcan.gc.ca/division"
    product_label: "finance.statcan.gc.ca/workload-id"
    product_external_label: "wid"
    environment_label: "project.statcan.gc.ca/environment"
  gpuLabel: "node.statcan.gc.ca/use"
  gpuLabelValue: "gpu"
  sharedNamespaces: "${var.kubecost_shared_namespaces}"

prometheus:
  nodeExporter:
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - effect: NoSchedule
        operator: Exists
%{if length(var.kubecost_prometheus_node_selector) > 0~}
  nodeSelector:
    ${indent(4, yamlencode(var.kubecost_prometheus_node_selector))~}
%{endif~}

EOF
}
