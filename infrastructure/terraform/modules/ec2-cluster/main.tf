resource "aws_instance" "broker" {
  count = var.broker_count

  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [var.broker_security_group]
  associate_public_ip_address = true

  tags = {
    Name = "${var.name_prefix}-broker-${count.index + 1}"
    Role = "kafka-broker"
  }
}

resource "aws_instance" "benchmark_client" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [var.client_security_group]
  associate_public_ip_address = true

  tags = {
    Name = var.benchmark_client_name
    Role = "benchmark-client"
  }
}
