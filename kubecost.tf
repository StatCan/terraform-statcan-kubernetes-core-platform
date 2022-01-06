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

  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-kubecost.git?ref=v3.x"

  depends_on = [
    kubernetes_namespace.kubecost_system
  ]

  helm_namespace           = kubernetes_namespace.kubecost_system.id
  helm_repository          = lookup(var.platform_helm_repositories, "cost-analyzer", "https://kubecost.github.io/cost-analyzer")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  values = <<EOF
# Default values for cost-analyzer.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

global:
  savedReports:
    enabled: false

  assetReports:
    enabled: false

  notifications:
    alertConfigs:
      frontendUrl: "kubecost.${var.ingress_domain}"
      globalSlackWebhookUrl: "${var.kubecost_slack_token}"
      globalAlertEmails:
        - brendan.gadd@canada.ca
        - william.hearn@canada.ca
        - zachary.seguin@canada.ca

      alerts:
        - type: budget
          threshold: 1000
          window: daily
          aggregation: cluster
          filter: cluster-one

        - type: budget
          threshold: 50
          window: daily
          aggregation: namespace
          filter: "minio-operator-system,minio-premium-system,minio-standard-system"
          ownerContact:
            - william.hearn@canada.ca
            - zachary.seguin@canada.ca

        - type: recurringUpdate
          window: weekly
          aggregation: namespace
          filter: '*'

        - type: spendChange
          relativeThreshold: 0.20
          window: 1d
          baselineWindow: 30d
          aggregation: namespace
          filter: "${var.kubecost_shared_namespaces}"

        - type: health
          window: 10m
          threshold: 5

        - type: diagnostic
          window: 10m

    alertmanager:
      enabled: false

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
  image: "${local.repositories.gcr}kubecost1/kubecost-network-costs:v15.6"

clusterController:
  image: "${local.repositories.gcr}kubecost1/cluster-controller:v0.0.2"

initChownDataImage: "${local.repositories.dockerhub}busybox"

tolerations:
  - key: CriticalAddonsOnly
    operator: Exists

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: istio
  hosts:
    - "kubecost.${var.ingress_domain}"
  paths:
    - '/*'

prometheus:
  nodeExporter:
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - effect: NoSchedule
        operator: Exists

  alertmanager:
    enabled: true
  
%{if length(var.kubecost_prometheus_node_selector) > 0~}
  nodeSelector:
    indent(4, yamldecode(var.kubecost_prometheus_node_selector)
%{endif}    


kubecostProductConfigs:
  clusterName: "${var.cluster_name}"
  clusterProfile: ${var.kubecost_cluster_profile}
  currencyCode: "CAD"
  labelMappingConfigs:
    enabled: true
    # owner_label: "owner"
    # team_label: "team"
    # department_label: "dept"
    product_label: "finance.statcan.gc.ca/workload-id"
    # environment_label: "env"
    # namespace_external_label: "kubernetes_namespace"
    # cluster_external_label: "kubernetes_cluster"
    # controller_external_label: "kubernetes_controller"
    product_external_label: "wid"
    # service_external_label: "kubernetes_service"
    # deployment_external_label: "kubernetes_deployment"
    # owner_external_label: "kubernetes_label_owner"
    # team_external_label: "kubernetes_label_team"
    # environment_external_label: "kubernetes_label_env"
    # department_external_label: "kubernetes_label_department"
    # statefulset_external_label: "kubernetes_statefulset"
    # daemonset_external_label: "kubernetes_daemonset"
    # pod_external_label: "kubernetes_pod"
  gpuLabel: "node.statcan.gc.ca/use"
  gpuLabelValue: "gpu"
  azureBillingRegion: CA
  azureSubscriptionID: ${var.subscription_id}
  azureClientID: ${var.kubecost_client_id}
  azureClientPassword: ${var.kubecost_client_secret}
  azureTenantID: ${var.tenant_id}
  azureStorageAccount: ${var.kubecost_storage_account}
  azureStorageAccessKey: ${var.kubecost_storage_access_key}
  azureStorageContainer: ${var.kubecost_storage_container}
  azureStorageCreateSecret: true
  sharedNamespaces: "${var.kubecost_shared_namespaces}"
  productKey:
    enabled: true
    key: ${var.kubecost_product_key}
  createServiceKeySecret: true
EOF
}
