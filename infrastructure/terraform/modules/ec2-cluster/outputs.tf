output "broker_public_ips" {
  value = aws_instance.broker[*].public_ip
}

output "broker_private_ips" {
  value = aws_instance.broker[*].private_ip
}

output "benchmark_client_public_ip" {
  value = aws_instance.benchmark_client.public_ip
}

output "benchmark_client_private_ip" {
  value = aws_instance.benchmark_client.private_ip
}
