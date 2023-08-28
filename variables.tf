variable "cluster_name" {
  description = "Name of the cluster"
}

variable "ci_service_account_name" {
  default     = "ci"
  description = "Name of the CI service account."
}

variable "cluster_resource_group_name" {

}

variable "cluster_node_resource_group_name" {

}

variable "subscription_id" {

}

variable "tenant_id" {

}

variable "administrative_groups" {
  type        = list(string)
  description = "List of groups who have administrative access to system namespaces."
}

variable "platform_image_repository_credentials_enable" {
  type    = bool
  default = false
}

variable "platform_image_bases" {
  type        = map(string)
  description = "Overwrite base image location (MUST contain a trailing slash)"

  default = {}
}

variable "platform_image_repository" {
  default = "docker.io"
}

variable "platform_image_repository_username" {
  default     = ""
  description = "The username for the repository where the image is stored"
  sensitive   = true
}

variable "platform_image_repository_password" {
  default     = ""
  description = "The password for the repository where the image is stored"
  sensitive   = true
}

variable "platform_image_repository_email" {
  default     = ""
  description = "The email for the repository where the image is stored"
  sensitive   = true
}

variable "platform_image_repository_auth" {
  default = ""
}

variable "platform_helm_repositories" {
  type    = map(string)
  default = {}
  # default = {
  #   aad_pod_identity = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  #   gatekeeper = "https://open-policy-agent.github.io/gatekeeper/charts"
  #   prometheus = "https://statcan.github.com/charts"
  # }
}

variable "platform_helm_repository_username" {
  default     = ""
  description = "The username of the repository where the Helm chart is stored"
  sensitive   = true
}

variable "platform_helm_repository_password" {
  default     = ""
  description = "The password of the repository where the Helm chart is stored"
  sensitive   = true
}

variable "ingress_domain" {
}

# Cert Manager

variable "cert_manager_identity_client_id" {
  description = "Client ID associated with the Azure Managed Identity for cert-manager"
}

variable "cert_manager_identity_id" {
  description = "ID of the Azure Managed Identity for cert-manager"
}

variable "cert_manager_subscription_id" {

}

variable "cert_manager_resource_group_name" {

}

variable "cert_manager_hosted_zone_name" {

}

# gatekeeper controller pods

variable "gk_replicas" {
  description = "The number of replicas of gatekeeper controller pods"
  default     = "3"
}

variable "gk_limits_cpu" {
  description = "max cpu allocated for gatekeeper controller pods"
  default     = "1000m"
}

variable "gk_requests_cpu" {
  description = "min cpu allocated for gatekeeper controller pods"
  default     = "100m"
}

variable "gk_limits_memory" {
  description = "max cpu allocated for gatekeeper controller pods"
  default     = "1528Mi"
}

variable "gk_requests_memory" {
  description = "min cpu allocated for gatekeeper audit pods"
  default     = "1024Mi"
}

# gatekeeper audit pods

variable "gk_audit_limits_cpu" {
  description = "max cpu allocated for gatekeeper audit pods"
  default     = "1000m"
}

variable "gk_audit_requests_cpu" {
  description = "min cpu allocated for gatekeeper controller pods"
  default     = "100m"
}

variable "gk_audit_limits_memory" {
  description = "max mem allocated for gatekeeper audit pods"
  default     = "1528Mi"
}

variable "gk_audit_requests_memory" {
  description = "min cpu allocated for gatekeeper audit pods"
  default     = "1024Mi"
}

# Grafana

variable "grafana_client_id" {

}

variable "grafana_client_secret" {
  sensitive = true

}

# Velero

variable "backup_resource_group_name" {

}

variable "velero_identity_client_id" {

}

variable "velero_identity_id" {

}

variable "velero_storage_account" {

}

variable "velero_storage_bucket" {

}

# Vault

variable "vault_address" {

}

# KubeCost

variable "kubecost" {
  type = object({
    cluster_profile   = string
    token             = string
    product_key       = string
    shared_namespaces = list(string)
    azure = object({
      client_id       = string
      client_password = string
    })
    metric_relabelings = optional(string, "")
    notifications = object({
      global_slack_webhook_url = optional(string, "")
      alerts                   = optional(string, "")
    })
  })
}

# Prometheus

variable "prometheus_disk_size" {
  default = "80Gi"
}

variable "prometheus_resources" {
  description = "The limits and requests to set on the Prometheus pod."
  type = object({
    limits   = map(string),
    requests = map(string),
  })
  default = {
    limits   = {},
    requests = {},
  }
}

variable "additional_alertmanagers" {
  description = "List of additional Alertmanager target URLs for the Platform Prometheus"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for alertmanager in var.additional_alertmanagers : can(regex("^(http|https)://.+", alertmanager))
    ])

    error_message = "Must be a list of one or more URLs. Example: [\"http://my-svc:9093\", \"https://example-alertmanager.com\"]."
  }
}

variable "ingress_class_name" {
  description = "The name of the IngressClass cluster resource"
  type        = string
  default     = "ingress-istio-controller"
}

# FluentD

variable "global_fluentd_config" {
  description = "Global Fluentd config, usually used to define the default plugin"

  default = <<EOF
<plugin default>
  @type null
</plugin>
EOF
}

# Platform Event Logging

variable "logging_elasticsearch_url" {
  description = "URL to elasticsearch for logging"
}

variable "logging_elasticsearch_username" {
  description = "Elasticsearch username for logging"
  default     = ""
  sensitive   = true
}

variable "logging_elasticsearch_password" {
  description = "Elasticsearch password for logging"
  default     = ""
  sensitive   = true
}
