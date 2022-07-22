
resource "kubernetes_namespace" "prometheus_system" {
  metadata {
    name = "prometheus-system"

    labels = {
      "namespace.statcan.gc.ca/purpose"                = "system"
      "network.statcan.gc.ca/allow-ingress-controller" = "true"
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

  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-kube-prometheus-stack?ref=v2.0.0"

  chart_version = "36.2.1"
  depends_on = [
    kubernetes_namespace.prometheus_system
  ]

  helm_namespace           = kubernetes_namespace.prometheus_system.id
  helm_repository          = lookup(var.platform_helm_repositories, "prometheus", "https://prometheus-community.github.io/helm-charts")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password
  enable_destinationrules  = true
  enable_prometheusrules   = true

  values = <<EOF
# Default values for kube-prometheus-stack.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

global:
  imagePullSecrets:
  - name: "${local.platform_image_pull_secret_name}"

additionalPrometheusRulesMap:
  kubecostrules.yml:
    groups:
      - name: CPU
        rules:
          - expr: sum(rate(container_cpu_usage_seconds_total{container_name!=""}[5m]))
            record: cluster:cpu_usage:rate5m
          - expr: rate(container_cpu_usage_seconds_total{container_name!=""}[5m])
            record: cluster:cpu_usage_nosum:rate5m
          - expr: avg(irate(container_cpu_usage_seconds_total{container_name!="POD", container_name!=""}[5m])) by (container_name,pod_name,namespace)
            record: kubecost_container_cpu_usage_irate
          - expr: sum(container_memory_working_set_bytes{container_name!="POD",container_name!=""}) by (container_name,pod_name,namespace)
            record: kubecost_container_memory_working_set_bytes
          - expr: sum(container_memory_working_set_bytes{container_name!="POD",container_name!=""})
            record: kubecost_cluster_memory_working_set_bytes
      - name: Savings
        rules:
          - expr: sum(avg(kube_pod_owner{owner_kind!="DaemonSet"}) by (pod) * sum(container_cpu_allocation) by (pod))
            record: kubecost_savings_cpu_allocation
            labels:
              daemonset: "false"
          - expr: sum(avg(kube_pod_owner{owner_kind="DaemonSet"}) by (pod) * sum(container_cpu_allocation) by (pod)) / sum(kube_node_info)
            record: kubecost_savings_cpu_allocation
            labels:
              daemonset: "true"
          - expr: sum(avg(kube_pod_owner{owner_kind!="DaemonSet"}) by (pod) * sum(container_memory_allocation_bytes) by (pod))
            record: kubecost_savings_memory_allocation_bytes
            labels:
              daemonset: "false"
          - expr: sum(avg(kube_pod_owner{owner_kind="DaemonSet"}) by (pod) * sum(container_memory_allocation_bytes) by (pod)) / sum(kube_node_info)
            record: kubecost_savings_memory_allocation_bytes
            labels:
              daemonset: "true"

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

# NOTE ingress.ingressClassName will need to be set on kubernetes >=1.18
# REF https://kubernetes.io/blog/2020/04/02/improvements-to-the-ingress-api-in-kubernetes-1.18/#specifying-the-class-of-an-ingress
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
    annotations:
      kubernetes.io/ingress.class: istio

  sidecar:
    dashboards:
      searchNamespace: ALL
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
    selectorLabels:
      claim: platform-grafana

# NOTE ingress.ingressClassName will need to be set on kubernetes >=1.18
# REF https://kubernetes.io/blog/2020/04/02/improvements-to-the-ingress-api-in-kubernetes-1.18/#specifying-the-class-of-an-ingress
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
    image:
      repository: ${local.repositories.quay}prometheus/prometheus
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          storageClassName: default
          resources:
            requests:
              storage: ${var.prometheus_disk_size}
          selector:
            matchLabels:
              claim: platform-prometheus
    externalLabels:
      cluster: ${var.cluster_name}
    additionalScrapeConfigs:
    - job_name: kubecost
      honor_labels: true
      scrape_interval: 1m
      scrape_timeout: 10s
      metrics_path: /metrics
      scheme: http
      dns_sd_configs:
      - names:
        - kubecost-cost-analyzer.kubecost-system
        type: 'A'
        port: 9003
    additionalAlertManagerConfigs:
    - scheme: https
      static_configs:
      - targets: ['alertmanager.${var.ingress_domain}']
    additionalAlertRelabelConfigs:
    - source_labels: [severity]
      regex: '(info|warning|critical)'
      action: drop

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
  nodeSelector:
    kubernetes.io/os: linux
  service:
    port: 9751
    targetPort: 9751

  prometheus:
    monitor:
      relabelings:
        - sourceLabels: [__meta_kubernetes_pod_node_name]
          action: replace
          targetLabel: kubernetes_node

kube-state-metrics:
  image:
    repository: ${local.repositories.quay}coreos/kube-state-metrics
  imagePullSecrets:
  - name: "${local.platform_image_pull_secret_name}"
  tolerations:
  - key: CriticalAddonsOnly
    operator: Exists
EOF
}

resource "helm_release" "blackbox-exporter" {

  depends_on = [
    kubernetes_namespace.prometheus_system
  ]

  name                = "blackbox-exporter"
  namespace           = kubernetes_namespace.prometheus_system.id
  repository_username = var.platform_helm_repository_username
  repository_password = var.platform_helm_repository_password
  repository          = lookup(var.platform_helm_repositories, "blackbox-exporter", "https://prometheus-community.github.io/helm-charts")
  chart               = "prometheus-blackbox-exporter"
  version             = "4.10.4"

  values = [<<EOF
image:
  repository: ${local.repositories.dockerhub}prom/blackbox-exporter
  tag: v0.18.0
  pullPolicy: IfNotPresent
  pullSecrets:
  - name: "${local.platform_image_pull_secret_name}"

service:
  labels:
    app: prometheus-blackbox-exporter
    jobLabel: blackbox-exporter

pod:
  labels:
    app: prometheus-blackbox-exporter

serviceMonitor:
  enabled: true
  defaults:
    labels:
      app: prometheus-blackbox-exporter
      release: ${module.prometheus.helm_release}
  targets:
    - name: grafana
      url: https://grafana.${var.ingress_domain}
      interval: 60s
      scrapeTimeout: 60s
      module: http_2xx

EOF
  ]
}
