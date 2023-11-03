# This will already come deployed along with the cluster infraestructure
module "pooled-1" {
  source    = "git::__MODULE_SOURCE__//terraform//modules//tenant-apps?ref=v0.0.1"
  tenant_id = "pooled-1"
}

output "pooled-1_producer_irsa_role" {
  value = try(module.pooled-1.producer_irsa_role, null)
}

output "pooled-1_consumer_irsa_role" {
  value = try(module.pooled-1.consumer_irsa_role, null)
}
