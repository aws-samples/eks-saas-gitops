variable "tenant_id" {
  description = "Tentant identification"
  type        = string
}

variable "enable_producer" {
  description = "Defines if the Producer app will be deployed"
  type        = bool
  default     = true
}

variable "enable_consumer" {
  description = "Defines if the Consumer app will be deployed"
  type        = bool
  default     = true
}