# Terraform Infrastructure

This directory contains the infrastructure definition for the dissertation artefact's AWS deployment.

## Current Intent

The infrastructure will provision a small EC2-based Kafka benchmark environment with:

- a VPC
- one public subnet for initial access
- security groups for SSH and Kafka traffic
- Kafka broker EC2 instances
- one benchmark controller/client EC2 instance

The first implementation target is a development environment that can later be extended into a more realistic multi-subnet layout if needed.

## Initial AWS Assumptions

The first deployment baseline assumes:

- region: `eu-west-2`
- operating system family: `Ubuntu 24.04 LTS`
- broker and client instance type: `t3.large`
- broker count: `3`
- benchmark client count: `1`

These defaults are intended to provide a moderate-cost starting point for framework validation. They are not yet the final dissertation evaluation configuration.

## Operational Note

SSH access to the brokers and benchmark client is controlled by `allowed_ssh_cidrs` in a local `infrastructure/terraform/envs/dev/terraform.tfvars` file. Create this file from `terraform.tfvars.example` and keep the real file out of Git, because it contains environment-specific access-control values.

If the operator's public IP changes, EC2 instance health checks may remain green while all orchestration SSH commands time out. When that happens, update the local allowlist to the current `/32` and, if immediate access is required, apply the matching change to the live security groups.

## State And Secret Handling

Terraform state and local variables are generated operational state, not source files. Do not commit:

- `terraform.tfstate` or `terraform.tfstate.*`
- `.terraform.tfstate.lock.info`
- `terraform.tfvars` or `*.tfvars.json`
- generated SSH keys, TLS keys, certificates, keystores, or truststores

If any of these files are committed accidentally, rotate the affected credentials or keys and remove the files from Git history before publishing the repository.

## Planned Topology

```text
AWS VPC
  |
  +-- Public Subnet
        |
        +-- kafka-broker-1
        +-- kafka-broker-2
        +-- kafka-broker-3
        +-- benchmark-client
```

## Scope Boundary

This Terraform layer is responsible for provisioning infrastructure only. Kafka installation, TLS/mTLS certificate setup, benchmark execution, and results collection will be handled separately by deployment scripts and artefact code.

## Next Steps

1. Add provider and backend configuration.
2. Finalise instance sizing and region.
3. Add bootstrap or provisioning scripts for Kafka installation.
4. Separate security groups for broker internal traffic and client access.
