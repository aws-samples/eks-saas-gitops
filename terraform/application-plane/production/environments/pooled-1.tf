# This will already come deployed along with the cluster infraestructure
locals {}

module "pooled_1" {
  source = "git::__MODULE_SOURCE__//terraform//modules//tenant-apps?ref=v0.0.1"
  bucket_name = "pool-1"
}