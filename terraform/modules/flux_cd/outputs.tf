output "flux_namespace" {
  description = "The namespace where Flux is installed"
  value       = kubernetes_namespace.flux_system.metadata[0].name
}

output "flux_secret_name" {
  description = "The name of the Flux secret for Git authentication"
  value       = kubernetes_secret.flux_system.metadata[0].name
}