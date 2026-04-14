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
