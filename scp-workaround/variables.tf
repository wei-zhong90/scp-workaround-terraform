variable "bucket_name" {
  type        = string
  description = "the bucket that will be used by cloudtrail"
}

variable "trail_name" {
  type        = string
  description = "the tail name"
  default     = "org_monitor_trail"
}

variable "tags" {
  description = "Any additional tags that should be added to taggable resources created by this module."
  type        = map(string)
  default     = {}
}

variable "lambda_function_name" {
  type        = string
  description = "the function name"
  default     = "scp-control-function"
}

variable "profile" {
  type    = string
  default = "default"
}
