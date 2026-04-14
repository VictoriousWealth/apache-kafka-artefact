variable "name_prefix" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "broker_security_group" {
  type = string
}

variable "client_security_group" {
  type = string
}

variable "broker_count" {
  type = number
}

variable "benchmark_client_name" {
  type = string
}
