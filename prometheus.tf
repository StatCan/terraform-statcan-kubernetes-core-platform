
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
  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

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

locals {
  grafana_host = "grafana.${var.ingress_domain}"
}

module "prometheus" {
  providers = {
    helm = helm
  }

  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-kube-prometheus-stack?ref=v3.8.3"

  chart_version = "43.3.0"
  depends_on = [
    kubernetes_namespace.prometheus_system
  ]

  helm_namespace           = kubernetes_namespace.prometheus_system.id
  helm_repository          = lookup(var.platform_helm_repositories, "prometheus", "https://prometheus-community.github.io/helm-charts")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password
  enable_destinationrules  = true

  values = <<EOF
# Default values for kube-prometheus-stack.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

global:
  imagePullSecrets:
  - name: "${local.platform_image_pull_secret_name}"

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
        registry: ${trimsuffix(local.repositories.k8sreg, "/")}
        repository: ingress-nginx/kube-webhook-certgen
  image:
    registry: ${trimsuffix(local.repositories.quay, "/")}
    repository: prometheus-operator/prometheus-operator
  prometheusConfigReloaderImage:
    registry: ${trimsuffix(local.repositories.quay, "/")}
    repository: prometheus-operator/prometheus-config-reloader

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
    ingressClassName: ${var.ingress_class_name}
    hosts:
      - ${local.grafana_host}
    path: /
    pathType: Prefix

  sidecar:
    dashboards:
      searchNamespace: ALL
    datasources:
      defaultDataSourceEnabled: false
    image:
      repository: ${local.repositories.dockerhub}kiwigrid/k8s-sidecar

  grafana.ini:
    server:
      root_url: https://${local.grafana_host}
    auth.ldap:
      enabled: false
    auth.azuread:
      enabled: true
      name: "Azure AD"
      allow_sign_up: true
      client_id: "$__file{/etc/secrets/auth_azuread/client_id}"
      client_secret: "$__file{/etc/secrets/auth_azuread/client_secret}"
      scopes: "openid email profile"
      auth_url: "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/authorize"
      token_url: "https://login.microsoftonline.com/${var.tenant_id}/oauth2/v2.0/token"
      allowed_domains: ""
      allowed_groups: ""
      role_attribute_strict: false

  ldap:
    enabled: false

  persistence:
    enabled: true
    storageClassName: default
    accessModes: ["ReadWriteOnce"]
    size: 20Gi
    selectorLabels:
      claim: platform-grafana

  extraSecretMounts:
    - name: auth-azuread-oauth-secret-mount
      secretName: ${kubernetes_secret.grafana_azuread_oauth.metadata.0.name}
      defaultMode: 0440
      mountPath: /etc/secrets/auth_azuread
      readOnly: true

prometheus:
  ingress:
    enabled: true
    ingressClassName: ${var.ingress_class_name}
    hosts:
      - prometheus.${var.ingress_domain}
    paths:
      - /
    pathType: Prefix
    annotations:
      ingress.statcan.gc.ca/gateways: istio-system/authenticated-istio-ingress-gateway-https

  prometheusSpec:
    image:
      registry: ${trimsuffix(local.repositories.quay, "/")}
      repository: prometheus/prometheus
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
    ${trimspace(indent(4, var.prometheus_additional_scrape_config))}
    additionalAlertManagerConfigs:
    - scheme: https
      static_configs:
      - targets:
        - alertmanager-0.cloud.statcan.ca
        - alertmanager-1.cloud.statcan.ca
## Construct additional entries using regex with 2 capture groups: http or https (the only acceptable values) for the scheme and the FQDN for the target
%{for alertmanager in var.additional_alertmanagers~}
    - scheme: ${regex("^(http|https)://(.+)", alertmanager)[0]}
      static_configs:
      - targets:
        - ${regex("^(http|https)://(.+)", alertmanager)[1]}
%{endfor~}
    additionalAlertRelabelConfigs:
    - source_labels: [severity]
      regex: '(info|warning|critical)'
      action: drop
    - source_labels: [alertname]
      regex: 'InfoInhibitor'
      action: drop

    resources:
      ${indent(6, yamlencode(var.prometheus_resources))}

    ## If true, a nil or {} value for prometheus.prometheusSpec.serviceMonitorSelector will cause the
    ## prometheus resource to be created with selectors based on values in the helm deployment,
    ## which will also match the servicemonitors created
    ##
    serviceMonitorSelectorNilUsesHelmValues: false

    ## ServiceMonitors to be selected for target discovery.
    ## If {}, select all ServiceMonitors
    ##
    serviceMonitorSelector: {}

    ## Namespaces to be selected for ServiceMonitor discovery.
    ##
    serviceMonitorNamespaceSelector:
      matchLabels:
        namespace.statcan.gc.ca/purpose: system

    ## If true, a nil or {} value for prometheus.prometheusSpec.podMonitorSelector will cause the
    ## prometheus resource to be created with selectors based on values in the helm deployment,
    ## which will also match the podmonitors created
    ##
    podMonitorSelectorNilUsesHelmValues: false

    ## PodMonitors to be selected for target discovery.
    ## If {}, select all PodMonitors
    ##
    podMonitorSelector: {}

    ## Namespaces to be selected for PodMonitor discovery.
    ## See https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#namespaceselector for usage
    ##
    podMonitorNamespaceSelector:
      matchLabels:
        namespace.statcan.gc.ca/purpose: system

    ## If true, a nil or {} value for prometheus.prometheusSpec.probeSelector will cause the
    ## prometheus resource to be created with selectors based on values in the helm deployment,
    ## which will also match the probes created
    ##
    probeSelectorNilUsesHelmValues: false

    ## Probes to be selected for target discovery.
    ## If {}, select all Probes
    ##
    probeSelector: {}

    ## Namespaces to be selected for Probe discovery.
    ## See https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#namespaceselector for usage
    ##
    probeNamespaceSelector:
      matchLabels:
        namespace.statcan.gc.ca/purpose: system

    ## Namespaces to be selected for PrometheusRules discovery.
    ## If nil, select own namespace. Namespaces to be selected for ServiceMonitor discovery.
    ## See https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#namespaceselector for usage
    ##
    ruleNamespaceSelector:
      matchLabels:
        namespace.statcan.gc.ca/purpose: system

    ## If true, a nil or {} value for prometheus.prometheusSpec.ruleSelector will cause the
    ## prometheus resource to be created with selectors based on values in the helm deployment,
    ## which will also match the PrometheusRule resources created
    ##
    ruleSelectorNilUsesHelmValues: false

alertmanager:
  enabled: false

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
    repository: ${local.repositories.k8sreg}kube-state-metrics/kube-state-metrics
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

resource "kubernetes_secret" "grafana_azuread_oauth" {
  metadata {
    name      = "auth-azuread-oauth-secret"
    namespace = kubernetes_namespace.prometheus_system.id
  }

  data = {
    client_id     = var.grafana_client_id
    client_secret = var.grafana_client_secret
  }
}
