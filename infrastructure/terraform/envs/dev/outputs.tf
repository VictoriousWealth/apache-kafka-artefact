output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_id" {
  value = module.network.public_subnet_id
}

output "broker_public_ips" {
  value = module.ec2_cluster.broker_public_ips
}

output "benchmark_client_public_ip" {
  value = module.ec2_cluster.benchmark_client_public_ip
}
