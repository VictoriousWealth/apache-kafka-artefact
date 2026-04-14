terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "../../modules/network"

  name_prefix        = var.name_prefix
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  aws_region         = var.aws_region
  allowed_ssh_cidrs  = var.allowed_ssh_cidrs
}

module "ec2_cluster" {
  source = "../../modules/ec2-cluster"

  name_prefix           = var.name_prefix
  ami_id                = var.ami_id
  instance_type         = var.instance_type
  key_name              = var.key_name
  subnet_id             = module.network.public_subnet_id
  broker_security_group = module.network.kafka_security_group_id
  client_security_group = module.network.client_security_group_id
  broker_count          = var.broker_count
  benchmark_client_name = "${var.name_prefix}-benchmark-client"
}
