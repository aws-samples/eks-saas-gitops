provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.ca)
  token                  = var.token
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.ca)
    token                  = var.token
  }
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "helm_release" "flux2-sync" {
  name       = "flux-system"
  namespace   = var.namespace
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"

  values = ["${file("${var.values_path}")}"]

  set {
    name = "secret.create"
    value = true
  }

  # set {
  #   name  = "secret.data"
  #   value = yamlencode({
  #     username = var.git_username
  #     password = var.git_password
  #   })
  # }

  set {
    name = "gitRepository.spec.ref.branch"
    value = var.git_branch
  }

  set {
    name = "gitRepository.spec.url"
    value = var.git_url # The repository URL, can be an HTTP/S or SSH address.
  }

  set {
    name = "kustomization.spec.path"
    value = var.kustomization_path
  }

  depends_on = [helm_release.flux2, kubernetes_namespace.flux_system]
}

# TODO: Implement IRSA and change the Service Account name, for Image Controller
resource "helm_release" "flux2" {
  name       = "flux2"
  namespace   = var.namespace
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"

  set {
    name = "helmController.create"
    value = var.activate_helm_controller
  }

  set {
    name = "imageAutomationController.create"
    value = var.activate_image_automation_controller
  }
  
  set {
    name = "imageAutomationController.serviceAccount.annotations"
    value = var.image_automation_controller_sa_annotations
  }

  set {
    name = "imageReflectionController.create"
    value = var.activate_image_reflection_controller
  }

  set {
    name = "imageReflectionController.serviceAccount.annotations"
    value = var.image_reflection_controller_sa_annotations
  }

  set {
    name = "kustomizeController.create"
    value = var.activate_kustomize_controller
  }

  set {
    name = "notificationController.create"
    value = var.activate_notification_controller
  }

  set {
    name = "sourceController.create"
    value = var.activate_source_controller
  }
  
  depends_on = [kubernetes_namespace.flux_system]
}