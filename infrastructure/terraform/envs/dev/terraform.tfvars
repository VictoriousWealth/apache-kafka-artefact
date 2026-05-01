aws_region        = "eu-west-2"
name_prefix       = "kafka-artefact-dev"
ami_id            = "ami-0bc9640685b706689"
instance_type     = "t3.large"
key_name          = "kafka-artefact-dev-key"
allowed_ssh_cidrs = ["213.143.14.182/32"]
broker_count      = 3
