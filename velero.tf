
resource "kubernetes_namespace" "velero_system" {
  metadata {
    name = "velero-system"

    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
    }
  }
}

module "namespace_velero_system" {
  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.velero_system.id
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

module "velero_identity" {
  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-aad-pod-identity-template.git?ref=v2.x"

  depends_on = [
    module.aad_pod_identity
  ]

  identity_name = "velero"
  namespace     = kubernetes_namespace.velero_system.id

  type        = 0
  client_id   = var.velero_identity_client_id
  resource_id = var.velero_identity_id
}

module "velero" {
  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-velero.git?ref=v6.0.0"

  chart_version = "4.0.3"
  depends_on = [
    module.velero_identity
  ]

  helm_namespace = kubernetes_namespace.velero_system.id

  helm_repository = {
    name     = lookup(var.platform_helm_repositories, "velero", "https://vmware-tanzu.github.io/helm-charts")
    username = var.platform_helm_repository_username
    password = var.platform_helm_repository_password
  }

  cloud_provider_credentials = {
    client_id       = ""
    client_secret   = ""
    resource_group  = var.cluster_node_resource_group_name
    subscription_id = var.subscription_id
    tenant_id       = var.tenant_id
  }

  enable_prometheusrules = true

  values = <<EOF
image:
  repository: ${local.repositories.dockerhub}velero/velero
  pullPolicy: IfNotPresent
  imagePullSecrets:
    - "${local.platform_image_pull_secret_name}"

tolerations:
  - key: CriticalAddonsOnly
    operator: Exists

podLabels:
  aadpodidbinding: velero

# Assign resource limits
resources:
  requests:
    cpu: '1'
    memory: 512Mi
  limits:
    cpu: '1'
    memory: 1Gi

initContainers:
  - name: velero-plugin-for-azure
    image: ${local.repositories.dockerhub}velero/velero-plugin-for-microsoft-azure:v1.7.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

kubectl:
  image:
    repository: ${local.repositories.dockerhub}bitnami/kubectl

# Prometheus Operator ServiceMonitor for Velero metrics
metrics:
  serviceMonitor:
    enabled: true

configuration:
  # Parameters for the `default` BackupStorageLocation. See
  # https://velero.io/docs/v1.0.0/api-types/backupstoragelocation/
  backupStorageLocation:
  - name: ${var.cluster_name}
    default: true
    provider: azure
    bucket: ${var.velero_storage_bucket}
    config:
      subscriptionId: ${var.subscription_id}
      resourceGroup: ${var.backup_resource_group_name}
      storageAccount: ${var.velero_storage_account}
  # Parameters for the `default` VolumeSnapshotLocation. See
  # https://velero.io/docs/v1.0.0/api-types/volumesnapshotlocation/
  volumeSnapshotLocation:
    # Cloud provider where volume snapshots are being taken. Usually
    # should match `configuration.provider`. Required.,
  - name: ${var.cluster_name}
    provider: azure
    config:
      resourceGroup: ${var.backup_resource_group_name}
      incremental: true

# Backup schedules to create.
schedules:
  hourly-resources:
    schedule: "0 * * * *"
    template:
      includeClusterResources: true
      includedNamespaces:
      - '*'
      snapshotVolumes: false
      storageLocation: ${var.cluster_name}
      volumeSnapshotLocations:
      - ${var.cluster_name}
      ttl: 720h0m0s
EOF
}
