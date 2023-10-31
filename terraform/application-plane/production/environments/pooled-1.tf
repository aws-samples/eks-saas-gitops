# This will already come deployed along with the cluster infraestructure
module "pooled-1" {
  source    = "git::__MODULE_SOURCE__//terraform//modules//tenant-apps?ref=v0.0.1"
  tenant_id = "pooled-1"
}

output "pooled-1_producer_sqs_arn" {
  value = "${module.pooled-1.producer_sqs_arn}"
}

output "pooled-1_consumer_ddb_arn" {
  value = "${module.pooled-1.consumer_ddb_arn}"
}
