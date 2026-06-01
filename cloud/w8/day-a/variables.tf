variable "owner" {
  description = "Owner name"
  type        = string
  default     = "Remmusss"
}

variable "environment" {
  description = "Logical environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "W8 Day-A"
  type        = string
  default     = "Remmusss-aws-accelerator-p2"
}

variable "tags" {
  description = "Simple key/value metadata"
  type        = map(string)
  default = {
    track = "cloud-devops"
    week  = "w8"
    day   = "a"
  }
}
