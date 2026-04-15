variable "aws_region" {
  type        = string
  description = "AWS region for the development benchmark environment."
  default     = "eu-west-2"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for naming AWS resources."
  default     = "kafka-artefact-dev"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet."
  default     = "10.20.1.0/24"
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDR ranges allowed to SSH into the instances."
  default     = ["0.0.0.0/0"]
}

variable "ami_id" {
  type        = string
  description = "AMI used for the EC2 instances."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type used for brokers and the benchmark client."
  default     = "t3.large"
}

variable "key_name" {
  type        = string
  description = "Existing AWS EC2 key pair name."
}

variable "broker_count" {
  type        = number
  description = "Number of Kafka broker instances to create."
  default     = 3
}

variable "root_volume_size_gb" {
  type        = number
  description = "Root EBS volume size for brokers and the benchmark client."
  default     = 40
}
