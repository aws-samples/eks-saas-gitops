output "flux_secret_name" {
  description = "The name of the Flux secret for Git authentication"
  value       = kubernetes_secret.flux_system.metadata[0].name
}