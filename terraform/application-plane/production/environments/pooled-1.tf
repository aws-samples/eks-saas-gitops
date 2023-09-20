# This will already come deployed along with the cluster infraestructure
locals {}

module "pooled_1" {
  source = "../../../modules/tenant-apps"
  bucket_name = "pool-1"
}