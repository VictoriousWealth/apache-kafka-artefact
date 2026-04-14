# Development Plan

## Goal

This document translates the artefact design into a concrete implementation sequence. The aim is to reach a working benchmark framework quickly while preserving dissertation alignment.

## Phase 1: Infrastructure Baseline

Objective:

- provision a small AWS EC2 environment with Terraform

Deliverables:

- VPC and subnet
- security groups
- broker instances
- benchmark client/controller instance

Exit criteria:

- Terraform can plan and provision the development environment
- instances are reachable and consistently named

## Phase 2: Plaintext Kafka Deployment

Objective:

- deploy Kafka in a minimal plaintext configuration

Deliverables:

- Kafka installation/bootstrap scripts
- baseline broker configuration
- topic creation workflow

Exit criteria:

- benchmark client can connect to the broker cluster
- test topic can be created
- producer and consumer connectivity is confirmed

## Phase 3: Synthetic Workload Runner

Objective:

- generate controlled producer and consumer traffic

Deliverables:

- workload configuration files
- producer benchmark runner
- consumer benchmark runner
- result directory structure

Exit criteria:

- at least one low-intensity workload can run successfully
- throughput output is persisted in a structured format

## Phase 4: Experiment Controller

Objective:

- automate end-to-end execution of scenarios

Deliverables:

- scenario loader
- orchestration scripts
- run metadata capture

Exit criteria:

- a single command can execute a named scenario and store its outputs

## Phase 5: TLS and mTLS Support

Objective:

- support secure Kafka transport configurations

Deliverables:

- certificate generation process
- TLS broker/client configuration
- mTLS broker/client configuration

Exit criteria:

- the same synthetic workload can be executed under `plaintext`, `tls`, and `mtls`

## Phase 6: Baseline Experiment Matrix

Objective:

- run the first dissertation-relevant comparison set

Deliverables:

- low, medium, and high workload profiles
- security-mode comparison runs
- structured results for later plotting

Exit criteria:

- complete matrix for `plaintext`, `tls`, and `mtls`
- repeatable output directories with traceable metadata

## Phase 7: Secondary Parameter Sweeps

Objective:

- extend the framework beyond the baseline matrix

Candidate variables:

- `message_size`
- `producer_count`
- `partition_count`
- `batch_size`
- `linger_ms`
- `acks`

Exit criteria:

- at least one justified one-factor-at-a-time secondary sweep is runnable

## Immediate Priority

The next implementation work should focus on:

1. finalising AWS environment assumptions
2. adding instance bootstrap scripts
3. defining the first workload and scenario config files
4. deciding whether the benchmark clients will be Kafka-native tools, custom scripts, or a hybrid approach
