variable "region" {
  type    = string
  default = "us-west-2"
}

variable "aws_profile" {
  type    = string
  default = "default"
}

variable "project_name" {
  type    = string
  default = "Lab day C"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_username" {
  type    = string
  default = "admin"
}

variable "web_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
