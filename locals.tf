locals {
  platform_image_pull_secret_name = "platform-images"

  # Must contain trailing slash
  repositories = {
    dockerhub = lookup(var.platform_image_bases, "dockerhub", "docker.io/")
    gcr       = lookup(var.platform_image_bases, "gcr", "gcr.io/")
    mcr       = lookup(var.platform_image_bases, "mcr", "mcr.microsoft.com/")
    quay      = lookup(var.platform_image_bases, "quay", "quay.io/")
    k8s       = lookup(var.platform_image_bases, "k8s", "k8s.gcr.io/")
    k8sreg    = lookup(var.platform_image_bases, "k8sreg", "registry.k8s.io/")
  }
}
