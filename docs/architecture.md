# Architecture

## Purpose

The artefact is a research-oriented benchmarking framework for measuring the performance impact of Kafka transport security configurations. It is not intended to be a general-purpose streaming platform or production service.

## Architecture Drivers

The design is driven by five constraints:

- Realistic Kafka deployment and configuration
- Support for `plaintext`, `TLS`, and `mTLS`
- Controlled one-factor-at-a-time experimentation
- Automated and repeatable execution
- Structured, reproducible result capture

## High-Level Components

### 1. Kafka Deployment Layer

This layer provides the brokers and cluster configuration under test.

Responsibilities:

- Start and stop Kafka services
- Apply broker configuration for each security mode
- Support topics, partitions, and replication settings
- Provide a stable and repeatable environment for experiments

Planned location:

- `deploy/kafka/`

### 2. Certificate and Security Material Layer

This layer manages the files and scripts required for TLS and mTLS.

Responsibilities:

- Generate or store broker and client certificates
- Support trusted CA material
- Separate server-authenticated TLS from mutual-authenticated mTLS

Planned location:

- `deploy/certs/`

### 3. Workload Generation Layer

This layer drives data through the Kafka cluster.

Responsibilities:

- Produce synthetic messages under controlled rates and sizes
- Consume messages for end-to-end measurement under matching synthetic workloads
- Support configurable batching, acknowledgements, and concurrency

Planned location:

- `src/producer/`
- `src/consumer/`

### 4. Experiment Controller

This is the orchestration layer and the core of the artefact.

Responsibilities:

- Select scenarios and parameter values
- Start the correct deployment mode
- Run benchmark clients
- Collect and persist measurements
- Ensure consistent setup and teardown across runs

Planned location:

- `src/controller/`
- `scripts/`

### 5. Results and Analysis Preparation

This layer stores outputs from each benchmark run in a form suitable for later dissertation analysis.

Responsibilities:

- Store run metadata
- Store throughput and latency results
- Store optional host metrics
- Preserve scenario definitions alongside outputs

Planned location:

- `results/`

## Logical Execution Flow

The expected flow for a single run is:

1. Load an experiment scenario from `config/scenarios/`.
2. Load workload parameters from `config/workloads/`.
3. Provision or restart Kafka with the selected security mode.
4. Create or validate topics and partitions.
5. Start producer and consumer benchmark processes.
6. Capture benchmark metrics and run metadata.
7. Persist results to structured files in `results/`.
8. Reset or tear down the environment before the next run.

## Primary Architectural Views

### System Context

The operator interacts only with the experiment controller. The controller manages Kafka, benchmark clients, and result outputs.

```text
Researcher/Operator
        |
        v
Experiment Controller
   |       |        |
   v       v        v
Kafka   Benchmarks  Results Store
```

### Deployment View

The primary deployment model is AWS EC2 provisioned with Terraform:

```text
Terraform
   |
   v
AWS VPC
   |
   +-- Kafka Broker EC2 1
   +-- Kafka Broker EC2 2
   +-- Kafka Broker EC2 3
   +-- Benchmark Client / Controller EC2
```

For the earliest milestone, a single-broker setup may be used to validate the framework before expanding to a multi-broker layout. The target dissertation-grade architecture, however, is a small multi-VM Kafka deployment with fixed machine specifications.

### Data and Result Flow

```text
Scenario Config -> Controller -> Kafka Mode Selection -> Benchmark Run -> Raw Metrics -> Structured Results
```

## Configuration Boundaries

The design separates variables into:

- Primary independent variable:
  `security_mode`
- Secondary controllable variables:
  `broker_count`, `partition_count`, `replication_factor`, `message_size`, `producer_count`, `batch_size`, `acks`, `linger_ms`
- Dependent variables:
  `throughput`, `latency`, and optionally `cpu_usage`, `memory_usage`

This separation is necessary to keep the methodology academically defensible.

## Design Constraints

- The framework must not vary multiple major factors without explicitly recording that choice.
- The baseline comparison must be the same deployment and workload under different security modes.
- The system should prioritise automation over manual benchmark execution.
- Every result file should include enough metadata to explain how it was produced.
- The benchmark process should use custom synthetic workloads tailored to the research question rather than relying on external benchmark suites whose workload assumptions do not directly target the TLS/mTLS comparison.

## Initial Technical Decisions

- Deployment approach: `AWS EC2` provisioned with `Terraform`
- Initial benchmark focus: throughput first, latency second
- Initial comparison set: `plaintext`, `TLS`, `mTLS`
- Initial methodology: one-factor-at-a-time, with a justified subset of scenario combinations reported in the dissertation
