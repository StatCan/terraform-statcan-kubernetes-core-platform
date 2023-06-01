###
### EVENT LOGGING
###

resource "kubernetes_namespace" "event_logging_system" {
  metadata {
    name = "event-logging-system"
    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
    }
  }
}

module "namespace_event_logging_system" {
  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git?ref=v2.10.1"

  name = kubernetes_namespace.event_logging_system.metadata.0.name
  namespace_admins = {
    users  = []
    groups = var.administrative_groups
  }

  # CICD
  ci_name = var.ci_service_account_name

  # Image Pull Secret
  enable_kubernetes_secret = var.platform_image_repository_credentials_enable
  kubernetes_secret        = local.platform_image_pull_secret_name
  docker_repo              = var.platform_image_repository
  docker_username          = var.platform_image_repository_username
  docker_password          = var.platform_image_repository_password
  docker_email             = var.platform_image_repository_email
  docker_auth              = var.platform_image_repository_auth
}


resource "helm_release" "kubernetes_event_exporter" {
  name      = "kubernetes-event-exporter"
  namespace = kubernetes_namespace.event_logging_system.metadata[0].name

  repository = lookup(var.platform_helm_repositories, "kubernetes-event-exporter", "https://resmoio.github.io/kubernetes-event-exporter")

  repository_username = var.platform_helm_repository_username
  repository_password = var.platform_helm_repository_password

  chart   = "kubernetes-event-exporter"
  version = "0.1.0"

  # for clarity including this override since this chart for some reason
  # does not use the helm release namespace by default
  # see: https://github.com/resmoio/kubernetes-event-exporter/blob/f4b7ad969e5c78fd0538d5807ac3363066f8b17c/charts/kubernetes-event-exporter/values.yaml#L63
  set {
    name  = "namespaceOverride"
    value = kubernetes_namespace.event_logging_system.metadata[0].name
  }

  set {
    name  = "image.repository"
    value = "artifactory.cloud.statcan.ca/docker/resmoio/kubernetes-event-exporter"
  }

  set {
    name  = "image.tag"
    value = "v1.1"
  }

  set {
    name  = "resource.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "tolerations"
    value = yamlencode(local.tolerations)
  }

  values = [<<-EOF
  imagePullSecrets:
    - name: "${local.platform_image_pull_secret_name}"
  config: |
    logLevel: info
    logFormat: pretty
    clusterName: ${var.cluster_name}
    route:
      routes:
        - match:
          - receiver: "es"
    receivers:
      - name: "es"
        elasticsearch:
          hosts:
            - ${var.logging_elasticsearch_url}
          index: kubernetes-events
          indexFormat: "kubernetes-events-{2006.01.02}"
          username: ${var.logging_elasticsearch_username}
          password: ${var.logging_elasticsearch_password}
          layout:
            cluster_name: "{{ .ClusterName }}"
            timestamp: "{{ .LastTimestamp }}"
            message: "{{ .Message }}"
            reason: "{{ .Reason }}"
            type: "{{ .Type }}"
            count: "{{ .Count }}"
            kind: "{{ .InvolvedObject.Kind }}"
            name: "{{ .InvolvedObject.Name }}"
            annotations: "{{ toJson .InvolvedObject.Annotations }}"
            labels: "{{ toJson .InvolvedObject.Labels }}"
            namespace: "{{ .Namespace }}"
            reporter: "{{ .Source.Component }}"
            host: "{{ .Source.Host }}"
            related: "{{ toJson .Related }}"
  EOF
  ]

  depends_on = [module.namespace_event_logging_system]
}
