# Orchestration Plan

## Goal

This document describes how the infrastructure, Kafka bootstrap scripts, and later benchmark runner will be connected into a single deployment workflow.

## Initial Deployment Flow

The first end-to-end path targets a plaintext Kafka cluster on AWS EC2.

1. Terraform provisions the VPC, broker instances, and benchmark client instance.
2. Terraform outputs are collected and converted into node metadata.
3. Bootstrap scripts are copied to the broker nodes.
4. Kafka is installed on each broker.
5. A shared KRaft cluster ID is generated and distributed.
6. Each broker receives a node-specific `server.properties`.
7. Kafka is started as a `systemd` service on each broker.
8. The benchmark client node is prepared for later producer and consumer execution.

## Orchestration Responsibilities

The orchestration layer should:

- read Terraform outputs
- map broker IPs to node IDs
- derive the KRaft quorum voter string
- copy scripts and configuration templates to remote hosts
- execute the bootstrap sequence over SSH

## Scope Boundary

The initial orchestration scripts are for development only. They are intentionally simple and should avoid introducing unnecessary tools before the plaintext path is proven.

## Expected Inputs

- Terraform state or `terraform output -json`
- SSH private key path
- SSH username
- Kafka version assumptions

## Expected Outputs

- a running plaintext Kafka cluster
- a prepared benchmark client host
- saved node metadata for later experiment execution

## Future Extension

After the plaintext deployment works, the orchestration layer will extend to:

- TLS and mTLS certificate distribution
- client properties generation
- benchmark runner invocation
- result retrieval and storage
