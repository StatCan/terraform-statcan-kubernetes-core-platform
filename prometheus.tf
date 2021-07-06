
resource "kubernetes_namespace" "prometheus_system" {
  metadata {
    name = "prometheus-system"

    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
    }
  }
}

resource "random_password" "grafana_admin_password" {
  length      = 24
  special     = true
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

module "namespace_prometheus_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.prometheus_system.id
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

module "prometheus" {
  providers = {
    helm = helm
  }

  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-prometheus.git?ref=v3.x"

  depends_on = [
    kubernetes_namespace.prometheus_system
  ]

  helm_namespace           = kubernetes_namespace.prometheus_system.id
  helm_repository          = lookup(var.platform_helm_repositories, "prometheus", "https://statcan.github.io/charts")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  values = <<EOF
# Default values for prometheus-operator.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

global:
  imagePullSecrets:
  - name: "${local.platform_image_pull_secret_name}"

prometheus-operator:
  prometheusOperator:
    tolerations:
    - key: CriticalAddonsOnly
      operator: Exists
    admissionWebhooks:
      patch:
        tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
        image:
          repository: ${local.repositories.dockerhub}jettech/kube-webhook-certgen
    configmapReloadImage:
      repository: ${local.repositories.dockerhub}jimmidyson/configmap-reload
    hyperkubeImage:
      repository: ${local.repositories.k8s}hyperkube
    image:
      repository: ${local.repositories.quay}coreos/prometheus-operator
    prometheusConfigReloaderImage:
      repository: ${local.repositories.quay}coreos/prometheus-config-reloader
    tlsProxy:
      image:
        repository: ${local.repositories.dockerhub}squareup/ghostunnel

  grafana:
    adminPassword: ${random_password.grafana_admin_password.result}

    downloadDashboardsImage:
      repository: ${local.repositories.dockerhub}curlimages/curl
    image:
      repository: ${local.repositories.dockerhub}grafana/grafana
      pullSecrets:
        - "${local.platform_image_pull_secret_name}"
    initChownData:
      image:
        repository: ${local.repositories.dockerhub}busybox

    ingress:
      enabled: true
      hosts:
        - grafana.${var.ingress_domain}
      path: /.*
      annotations:
        kubernetes.io/ingress.class: istio

    sidecar:
      datasources:
        defaultDataSourceEnabled: false
      image:
        repository: ${local.repositories.dockerhub}kiwigrid/k8s-sidecar

    grafana.ini:
      auth.ldap:
        enabled: false

    ldap:
      enabled: false

    persistence:
      enabled: true
      storageClassName: default
      accessModes: ["ReadWriteOnce"]
      size: 20Gi

    tolerations:
    - key: CriticalAddonsOnly
      operator: Exists

  prometheus:
    ingress:
      enabled: true
      hosts:
        - prometheus.${var.ingress_domain}
      paths:
        - /.*
      annotations:
        kubernetes.io/ingress.class: istio

    prometheusSpec:
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
      image:
        repository: ${local.repositories.quay}prometheus/prometheus
      storageSpec:
        volumeClaimTemplate:
          spec:
            accessModes: ["ReadWriteOnce"]
            storageClassName: default
            resources:
              requests:
                storage: 80Gi
      externalLabels:
        cluster: ${var.cluster_name}

  alertmanager:
    ingress:
      enabled: true
      hosts:
        - alertmanager.${var.ingress_domain}
      paths:
        - /.*
      annotations:
        kubernetes.io/ingress.class: istio

    alertmanagerSpec:
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
      image:
        repository: ${local.repositories.quay}prometheus/alertmanager
      retention: 168h
      storage:
        volumeClaimTemplate:
          spec:
            accessModes: ["ReadWriteOnce"]
            storageClassName: default
            resources:
              requests:
                storage: 20Gi

  prometheus-node-exporter:
    image:
      repository: ${local.repositories.quay}prometheus/node-exporter
    serviceAccount:
      imagePullSecrets:
      - name: "${local.platform_image_pull_secret_name}"

  kube-state-metrics:
    image:
      repository: ${local.repositories.quay}coreos/kube-state-metrics
    imagePullSecrets:
    - name: "${local.platform_image_pull_secret_name}"
    tolerations:
    - key: CriticalAddonsOnly
      operator: Exists

destinationRule:
  enabled: false
EOF
}
