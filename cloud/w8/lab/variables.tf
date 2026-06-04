variable "region" {
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  type        = string
  default     = "default"
}

variable "project_name" {
  type        = string
  default     = "w8-lab"
}

variable "environment" {
  type        = string
  default     = "lab"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH. Leave null to skip key pair attachment."
  type        = string
  default     = null
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH into the EC2 host."
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.20.1.0/24"
}

variable "public_subnet_b_cidr" {
  type        = string
  default     = "10.20.2.0/24"
}

variable "nodeport" {
  type        = number
  default     = 32123

  validation {
    condition     = var.nodeport >= 30000 && var.nodeport <= 32767
    error_message = "nodeport must be within the Kubernetes NodePort range 30000-32767."
  }
}
