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

resource "kubernetes_secret" "flux_system" {
  metadata {
    name      = "flux-system"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }

  data = {
    username = var.gitea_username
    password = var.gitea_token
  }

  type = "Opaque"
}

resource "helm_release" "flux2-operator" {
  name       = "flux-operator"
  namespace  = var.namespace
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-operator"

  depends_on = [kubernetes_namespace.flux_system]
}

resource "kubernetes_manifest" "flux_instance" {
  manifest = {
    apiVersion = "fluxcd.controlplane.io/v1"
    kind       = "FluxInstance"
    metadata = {
      name      = "flux"
      namespace = "flux-system"
      annotations = {
        "fluxcd.controlplane.io/reconcileEvery"        = "1h"
        "fluxcd.controlplane.io/reconcileArtifactEvery" = "10m"
        "fluxcd.controlplane.io/reconcileTimeout"      = "5m"
      }
    }
    spec = {
      sync = {
        kind       = "GitRepository"
        url        = var.gitea_repo_url
        ref        = "refs/heads/main"
        path       = "clusters/production"
        pullSecret = "flux-system"
      }
      distribution = {
        version  = "2.x"
        registry = "ghcr.io/fluxcd"
        artifact = "oci://ghcr.io/controlplaneio-fluxcd/flux-operator-manifests"
      }
      components = [
        "source-controller",
        "kustomize-controller",
        "helm-controller",
        "notification-controller",
        "image-reflector-controller",
        "image-automation-controller"
      ]
      cluster = {
        type         = "kubernetes"
        multitenant  = false
        networkPolicy = true
        domain       = "cluster.local"
      }
      kustomize = {
        patches = [
          {
            target = {
              kind = "Deployment"
              name = "(kustomize-controller|helm-controller)"
            }
            patch = yamlencode([
              {
                op    = "add"
                path  = "/spec/template/spec/containers/0/args/-"
                value = "--concurrent=10"
              },
              {
                op    = "add"
                path  = "/spec/template/spec/containers/0/args/-"
                value = "--requeue-dependency=5s"
              }
            ])
          }
        ]
      }
    }
  }

  depends_on = [helm_release.flux2-operator]
}

# TODO: Implement IRSA and change the Service Account name, for Image Controller
# resource "helm_release" "flux2" {
#   name       = "flux2"
#   namespace  = var.namespace
#   repository = "https://fluxcd-community.github.io/helm-charts"
#   chart      = "flux2"
#   version    = var.flux2_version

#   set {
#     name  = "helmController.create"
#     value = var.activate_helm_controller
#   }

#   set {
#     name  = "imageAutomationController.create"
#     value = var.activate_image_automation_controller
#   }

#   set {
#     name  = "imageAutomationController.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = var.image_automation_controller_sa_annotations
#   }

#   set {
#     name  = "imageReflectionController.create"
#     value = var.activate_image_reflection_controller
#   }

#   set {
#     name  = "imageReflectionController.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = var.image_reflection_controller_sa_annotations
#   }

#   set {
#     name  = "kustomizeController.create"
#     value = var.activate_kustomize_controller
#   }

#   set {
#     name  = "notificationController.create"
#     value = var.activate_notification_controller
#   }

#   set {
#     name  = "sourceController.create"
#     value = var.activate_source_controller
#   }

#   depends_on = [kubernetes_namespace.flux_system]
# }
