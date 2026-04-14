variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidr" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "allowed_ssh_cidrs" {
  type = list(string)
}
