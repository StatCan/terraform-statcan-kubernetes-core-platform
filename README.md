## terraform-statcan-kubernetes-core-platform

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.0.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aad_pod_identity"></a> [aad\_pod\_identity](#module\_aad\_pod\_identity) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-aad-pod-identity.git | v3.0.0 |
| <a name="module_cert_manager"></a> [cert\_manager](#module\_cert\_manager) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-cert-manager.git | v5.5.0 |
| <a name="module_cert_manager_identity"></a> [cert\_manager\_identity](#module\_cert\_manager\_identity) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-aad-pod-identity-template.git | v2.x |
| <a name="module_cert_manager_letsencrypt"></a> [cert\_manager\_letsencrypt](#module\_cert\_manager\_letsencrypt) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-cert-manager-issuer.git | v1.3.0 |
| <a name="module_cert_manager_letsencrypt_staging"></a> [cert\_manager\_letsencrypt\_staging](#module\_cert\_manager\_letsencrypt\_staging) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-cert-manager-issuer.git | v1.3.0 |
| <a name="module_fluentd"></a> [fluentd](#module\_fluentd) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-fluentd.git | v3.0.1 |
| <a name="module_gatekeeper"></a> [gatekeeper](#module\_gatekeeper) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-open-policy-agent.git | v4.3.0 |
| <a name="module_kubecost"></a> [kubecost](#module\_kubecost) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-kubecost.git | v3.2.0 |
| <a name="module_namespace_aad_pod_identity_system"></a> [namespace\_aad\_pod\_identity\_system](#module\_namespace\_aad\_pod\_identity\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.2.0 |
| <a name="module_namespace_cert_manager_system"></a> [namespace\_cert\_manager\_system](#module\_namespace\_cert\_manager\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.2.0 |
| <a name="module_namespace_event_logging_system"></a> [namespace\_event\_logging\_system](#module\_namespace\_event\_logging\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.10.1 |
| <a name="module_namespace_fluentd_system"></a> [namespace\_fluentd\_system](#module\_namespace\_fluentd\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.2.0 |
| <a name="module_namespace_gatekeeper_system"></a> [namespace\_gatekeeper\_system](#module\_namespace\_gatekeeper\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.2.0 |
| <a name="module_namespace_kubecost_system"></a> [namespace\_kubecost\_system](#module\_namespace\_kubecost\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.2.0 |
| <a name="module_namespace_prometheus_system"></a> [namespace\_prometheus\_system](#module\_namespace\_prometheus\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.2.0 |
| <a name="module_namespace_statcan_system"></a> [namespace\_statcan\_system](#module\_namespace\_statcan\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.2.0 |
| <a name="module_namespace_vault_agent_system"></a> [namespace\_vault\_agent\_system](#module\_namespace\_vault\_agent\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.2.0 |
| <a name="module_namespace_velero_system"></a> [namespace\_velero\_system](#module\_namespace\_velero\_system) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git | v2.2.0 |
| <a name="module_prometheus"></a> [prometheus](#module\_prometheus) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-kube-prometheus-stack | v3.8.3 |
| <a name="module_vault_agent"></a> [vault\_agent](#module\_vault\_agent) | git::http://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-vault-agent.git | v1.0.1 |
| <a name="module_velero"></a> [velero](#module\_velero) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-velero.git | v5.2.1 |
| <a name="module_velero_identity"></a> [velero\_identity](#module\_velero\_identity) | git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-aad-pod-identity-template.git | v2.x |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_administrative_groups"></a> [administrative\_groups](#input\_administrative\_groups) | List of groups who have administrative access to system namespaces. | `list(string)` | n/a | yes |
| <a name="input_backup_resource_group_name"></a> [backup\_resource\_group\_name](#input\_backup\_resource\_group\_name) | n/a | `any` | n/a | yes |
| <a name="input_cert_manager_hosted_zone_name"></a> [cert\_manager\_hosted\_zone\_name](#input\_cert\_manager\_hosted\_zone\_name) | n/a | `any` | n/a | yes |
| <a name="input_cert_manager_identity_client_id"></a> [cert\_manager\_identity\_client\_id](#input\_cert\_manager\_identity\_client\_id) | Client ID associated with the Azure Managed Identity for cert-manager | `any` | n/a | yes |
| <a name="input_cert_manager_identity_id"></a> [cert\_manager\_identity\_id](#input\_cert\_manager\_identity\_id) | ID of the Azure Managed Identity for cert-manager | `any` | n/a | yes |
| <a name="input_cert_manager_resource_group_name"></a> [cert\_manager\_resource\_group\_name](#input\_cert\_manager\_resource\_group\_name) | n/a | `any` | n/a | yes |
| <a name="input_cert_manager_subscription_id"></a> [cert\_manager\_subscription\_id](#input\_cert\_manager\_subscription\_id) | n/a | `any` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster | `any` | n/a | yes |
| <a name="input_cluster_node_resource_group_name"></a> [cluster\_node\_resource\_group\_name](#input\_cluster\_node\_resource\_group\_name) | n/a | `any` | n/a | yes |
| <a name="input_cluster_resource_group_name"></a> [cluster\_resource\_group\_name](#input\_cluster\_resource\_group\_name) | n/a | `any` | n/a | yes |
| <a name="input_grafana_client_id"></a> [grafana\_client\_id](#input\_grafana\_client\_id) | n/a | `any` | n/a | yes |
| <a name="input_grafana_client_secret"></a> [grafana\_client\_secret](#input\_grafana\_client\_secret) | n/a | `any` | n/a | yes |
| <a name="input_ingress_domain"></a> [ingress\_domain](#input\_ingress\_domain) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_client_id"></a> [kubecost\_client\_id](#input\_kubecost\_client\_id) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_client_secret"></a> [kubecost\_client\_secret](#input\_kubecost\_client\_secret) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_cluster_profile"></a> [kubecost\_cluster\_profile](#input\_kubecost\_cluster\_profile) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_product_key"></a> [kubecost\_product\_key](#input\_kubecost\_product\_key) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_shared_namespaces"></a> [kubecost\_shared\_namespaces](#input\_kubecost\_shared\_namespaces) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_slack_token"></a> [kubecost\_slack\_token](#input\_kubecost\_slack\_token) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_storage_access_key"></a> [kubecost\_storage\_access\_key](#input\_kubecost\_storage\_access\_key) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_storage_account"></a> [kubecost\_storage\_account](#input\_kubecost\_storage\_account) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_storage_container"></a> [kubecost\_storage\_container](#input\_kubecost\_storage\_container) | n/a | `any` | n/a | yes |
| <a name="input_kubecost_token"></a> [kubecost\_token](#input\_kubecost\_token) | n/a | `any` | n/a | yes |
| <a name="input_logging_elasticsearch_url"></a> [logging\_elasticsearch\_url](#input\_logging\_elasticsearch\_url) | URL to elasticsearch for logging | `any` | n/a | yes |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | n/a | `any` | n/a | yes |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | n/a | `any` | n/a | yes |
| <a name="input_vault_address"></a> [vault\_address](#input\_vault\_address) | n/a | `any` | n/a | yes |
| <a name="input_velero_identity_client_id"></a> [velero\_identity\_client\_id](#input\_velero\_identity\_client\_id) | n/a | `any` | n/a | yes |
| <a name="input_velero_identity_id"></a> [velero\_identity\_id](#input\_velero\_identity\_id) | n/a | `any` | n/a | yes |
| <a name="input_velero_storage_account"></a> [velero\_storage\_account](#input\_velero\_storage\_account) | n/a | `any` | n/a | yes |
| <a name="input_velero_storage_bucket"></a> [velero\_storage\_bucket](#input\_velero\_storage\_bucket) | n/a | `any` | n/a | yes |
| <a name="input_additional_alertmanagers"></a> [additional\_alertmanagers](#input\_additional\_alertmanagers) | List of additional Alertmanager target URLs for the Platform Prometheus | `list(string)` | `[]` | no |
| <a name="input_ci_service_account_name"></a> [ci\_service\_account\_name](#input\_ci\_service\_account\_name) | Name of the CI service account. | `string` | `"ci"` | no |
| <a name="input_gk_audit_limits_cpu"></a> [gk\_audit\_limits\_cpu](#input\_gk\_audit\_limits\_cpu) | max cpu allocated for gatekeeper audit pods | `string` | `"1000m"` | no |
| <a name="input_gk_audit_limits_memory"></a> [gk\_audit\_limits\_memory](#input\_gk\_audit\_limits\_memory) | max mem allocated for gatekeeper audit pods | `string` | `"1528Mi"` | no |
| <a name="input_gk_audit_requests_cpu"></a> [gk\_audit\_requests\_cpu](#input\_gk\_audit\_requests\_cpu) | min cpu allocated for gatekeeper controller pods | `string` | `"100m"` | no |
| <a name="input_gk_audit_requests_memory"></a> [gk\_audit\_requests\_memory](#input\_gk\_audit\_requests\_memory) | min cpu allocated for gatekeeper audit pods | `string` | `"1024Mi"` | no |
| <a name="input_gk_limits_cpu"></a> [gk\_limits\_cpu](#input\_gk\_limits\_cpu) | max cpu allocated for gatekeeper controller pods | `string` | `"1000m"` | no |
| <a name="input_gk_limits_memory"></a> [gk\_limits\_memory](#input\_gk\_limits\_memory) | max cpu allocated for gatekeeper controller pods | `string` | `"1528Mi"` | no |
| <a name="input_gk_replicas"></a> [gk\_replicas](#input\_gk\_replicas) | The number of replicas of gatekeeper controller pods | `string` | `"3"` | no |
| <a name="input_gk_requests_cpu"></a> [gk\_requests\_cpu](#input\_gk\_requests\_cpu) | min cpu allocated for gatekeeper controller pods | `string` | `"100m"` | no |
| <a name="input_gk_requests_memory"></a> [gk\_requests\_memory](#input\_gk\_requests\_memory) | min cpu allocated for gatekeeper audit pods | `string` | `"1024Mi"` | no |
| <a name="input_global_fluentd_config"></a> [global\_fluentd\_config](#input\_global\_fluentd\_config) | Global Fluentd config, usually used to define the default plugin | `string` | `"<plugin default>\n  @type null\n</plugin>\n"` | no |
| <a name="input_ingress_class_name"></a> [ingress\_class\_name](#input\_ingress\_class\_name) | The name of the IngressClass cluster resource | `string` | `"ingress-istio-controller"` | no |
| <a name="input_kubecost_additional_alert_config"></a> [kubecost\_additional\_alert\_config](#input\_kubecost\_additional\_alert\_config) | Additional alerts for kubecost to pick up. Default should never trigger | `string` | `"- type: budget\n  threshold: 100000000000000\n  window: 1d\n  aggregation: namespace\n  filter: default\n"` | no |
| <a name="input_kubecost_alert_slack_webhook_url"></a> [kubecost\_alert\_slack\_webhook\_url](#input\_kubecost\_alert\_slack\_webhook\_url) | Kubecost global url for reporting alerts | `string` | `"https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"` | no |
| <a name="input_kubecost_prometheus_node_selector"></a> [kubecost\_prometheus\_node\_selector](#input\_kubecost\_prometheus\_node\_selector) | The nodeSelector to apply to the Prometheus instance backing Kubecost. | `map(string)` | `{}` | no |
| <a name="input_logging_elasticsearch_password"></a> [logging\_elasticsearch\_password](#input\_logging\_elasticsearch\_password) | Elasticsearch password for logging | `string` | `""` | no |
| <a name="input_logging_elasticsearch_username"></a> [logging\_elasticsearch\_username](#input\_logging\_elasticsearch\_username) | Elasticsearch username for logging | `string` | `""` | no |
| <a name="input_platform_helm_repositories"></a> [platform\_helm\_repositories](#input\_platform\_helm\_repositories) | n/a | `map(string)` | `{}` | no |
| <a name="input_platform_helm_repository_password"></a> [platform\_helm\_repository\_password](#input\_platform\_helm\_repository\_password) | The password of the repository where the Helm chart is stored | `string` | `""` | no |
| <a name="input_platform_helm_repository_username"></a> [platform\_helm\_repository\_username](#input\_platform\_helm\_repository\_username) | The username of the repository where the Helm chart is stored | `string` | `""` | no |
| <a name="input_platform_image_bases"></a> [platform\_image\_bases](#input\_platform\_image\_bases) | Overwrite base image location (MUST contain a trailing slash) | `map(string)` | `{}` | no |
| <a name="input_platform_image_repository"></a> [platform\_image\_repository](#input\_platform\_image\_repository) | n/a | `string` | `"docker.io"` | no |
| <a name="input_platform_image_repository_auth"></a> [platform\_image\_repository\_auth](#input\_platform\_image\_repository\_auth) | n/a | `string` | `""` | no |
| <a name="input_platform_image_repository_credentials_enable"></a> [platform\_image\_repository\_credentials\_enable](#input\_platform\_image\_repository\_credentials\_enable) | n/a | `bool` | `false` | no |
| <a name="input_platform_image_repository_email"></a> [platform\_image\_repository\_email](#input\_platform\_image\_repository\_email) | The email for the repository where the image is stored | `string` | `""` | no |
| <a name="input_platform_image_repository_password"></a> [platform\_image\_repository\_password](#input\_platform\_image\_repository\_password) | The password for the repository where the image is stored | `string` | `""` | no |
| <a name="input_platform_image_repository_username"></a> [platform\_image\_repository\_username](#input\_platform\_image\_repository\_username) | The username for the repository where the image is stored | `string` | `""` | no |
| <a name="input_prometheus_additional_scrape_config"></a> [prometheus\_additional\_scrape\_config](#input\_prometheus\_additional\_scrape\_config) | Default additional scrape configuration for prometheus | `string` | `"- job_name: kubecost\n  honor_labels: true\n  scrape_interval: 1m\n  scrape_timeout: 10s\n  metrics_path: /metrics\n  scheme: http\n  dns_sd_configs:\n  - names:\n    - kubecost-cost-analyzer.kubecost-system\n    type: 'A'\n    port: 9003\n"` | no |
| <a name="input_prometheus_disk_size"></a> [prometheus\_disk\_size](#input\_prometheus\_disk\_size) | n/a | `string` | `"80Gi"` | no |
| <a name="input_prometheus_resources"></a> [prometheus\_resources](#input\_prometheus\_resources) | The limits and requests to set on the Prometheus pod. | <pre>object({<br>    limits   = map(string),<br>    requests = map(string),<br>  })</pre> | <pre>{<br>  "limits": {},<br>  "requests": {}<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_grafana_url"></a> [grafana\_url](#output\_grafana\_url) | The URL for Grafana. |
| <a name="output_kube_prometheus_stack_namespace_name"></a> [kube\_prometheus\_stack\_namespace\_name](#output\_kube\_prometheus\_stack\_namespace\_name) | The name of the namespace where the kube-prometheus-stack is deployed. |
| <a name="output_kube_prometheus_stack_release_name"></a> [kube\_prometheus\_stack\_release\_name](#output\_kube\_prometheus\_stack\_release\_name) | The name of the release of the kube-prometheus-stack. |
<!-- END_TF_DOCS -->
