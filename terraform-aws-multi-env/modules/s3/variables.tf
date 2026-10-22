variable "env" {
  description = "Environment name (from terraform.workspace)"
  type        = string
}

variable "bucket_count" {
  description = "Number of S3 buckets to create"
  type        = number
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
