
resource "kubernetes_namespace" "velero_system" {
  metadata {
    name = "velero-system"

    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
    }
  }
}

module "namespace_velero_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

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
  source = "git::https://github.com/statcan/terraform-kubernetes-aad-pod-identity-template.git?ref=v2.x"

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
  source = "git::https://github.com/statcan/terraform-kubernetes-velero.git?ref=v4.x"

  chart_version = "2.30.2"
  depends_on = [
    module.velero_identity
  ]

  helm_namespace           = kubernetes_namespace.velero_system.id
  helm_repository          = lookup(var.platform_helm_repositories, "velero", "https://vmware-tanzu.github.io/helm-charts")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  backup_storage_resource_group = var.backup_resource_group_name
  backup_storage_account        = var.velero_storage_account
  backup_storage_bucket         = var.velero_storage_bucket

  azure_client_id       = ""
  azure_client_secret   = ""
  azure_resource_group  = var.cluster_node_resource_group_name
  azure_subscription_id = var.subscription_id
  azure_tenant_id       = var.tenant_id

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
    image: ${local.repositories.dockerhub}velero/velero-plugin-for-microsoft-azure:v1.5.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

kubectl:
  image:
    repository: ${local.repositories.dockerhub}bitnami/kubectl

configuration:
  # Cloud provider being used (e.g. aws, azure, gcp).
  provider: azure
  # Parameters for the `default` BackupStorageLocation. See
  # https://velero.io/docs/v1.0.0/api-types/backupstoragelocation/
  backupStorageLocation:
    name: ${var.cluster_name}
    default: true
  # Parameters for the `default` VolumeSnapshotLocation. See
  # https://velero.io/docs/v1.0.0/api-types/volumesnapshotlocation/
  volumeSnapshotLocation:
    # Cloud provider where volume snapshots are being taken. Usually
    # should match `configuration.provider`. Required.,
    name: ${var.cluster_name}
    config:
      resourceGroup: ${var.backup_resource_group_name}

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
