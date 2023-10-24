variable "bucket_name" {
  description = "Amazon S3 bucket name"
  type        = string
  default     = ""
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