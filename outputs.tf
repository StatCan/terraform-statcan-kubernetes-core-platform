output "grafana_url" {
  description = "The URL for Grafana."
  value       = "https://${local.grafana_host}"
}

output "kube_prometheus_stack_namespace_name" {
  description = "The name of the namespace where the kube-prometheus-stack is deployed."
  value       = kubernetes_namespace.prometheus_system.id
}

output "kube_prometheus_stack_release_name" {
  description = "The name of the release of the kube-prometheus-stack."
  value       = module.prometheus.helm_release
}
