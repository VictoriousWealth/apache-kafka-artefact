# Kafka Security Benchmarking Artefact

This repository contains the dissertation artefact for measuring Apache Kafka performance under controlled security and workload configurations. The current implemented path provisions an AWS EC2 Kafka cluster, deploys a plaintext Kafka baseline, runs a parameter sweep, parses raw Kafka benchmark output into structured metrics, and exports dissertation-ready tables and plots.

The long-term artefact goal is:

> A configurable Kafka benchmarking framework that supports controlled one-factor-at-a-time parameter sweeps over security and deployment variables, with primary emphasis on quantifying throughput and latency overhead under plaintext, TLS, and mTLS configurations.

## Current Status

Implemented:

- AWS infrastructure provisioning with Terraform.
- Three-broker Kafka KRaft cluster on EC2.
- One EC2 benchmark client.
- Plaintext Kafka deployment and readiness checks.
- Parameter sweep execution from JSON configuration.
- Kafka producer performance benchmark execution.
- Raw result parsing into `result.json`.
- Sweep-level aggregation into `summary.json` and `summary.csv`.
- Dissertation export layer producing CSV, LaTeX, and SVG plots.

Not implemented yet:

- TLS broker/client configuration.
- mTLS broker/client configuration.
- Certificate generation and rotation workflow.
- Consumer-side workload measurement.
- Host-level CPU, memory, disk, and network metric capture.

## Research Goal

The primary dissertation question is:

> What is the performance overhead introduced by zero-trust-inspired security mechanisms, particularly mTLS, in high-throughput Kafka-based distributed systems?

The artefact supports that question by creating repeatable Kafka deployments and running controlled synthetic workloads where one variable is changed at a time.

## System Overview

The system has five main layers:

- `infrastructure/terraform/`: provisions the AWS VPC, subnet, security groups, Kafka broker EC2 instances, and benchmark client EC2 instance.
- `deploy/kafka/`: contains Kafka installation scripts, broker configuration templates, client configuration, and the producer benchmark runner.
- `config/baselines/`: defines fixed baseline experiment settings.
- `config/sweeps/`: defines parameter ranges to test, for example message size or target throughput.
- `scripts/orchestration/`: connects Terraform outputs, remote bootstrap, benchmark execution, parsing, aggregation, and export.

Current AWS topology:

```text
AWS VPC
  |
  +-- Public subnet
        |
        +-- kafka-broker-1
        +-- kafka-broker-2
        +-- kafka-broker-3
        +-- benchmark-client
```

The scripts use public IPs for SSH access, but Kafka broker traffic uses private VPC IPs. This is important because Kafka quorum, advertised listeners, benchmark bootstrap servers, and readiness checks all run over the private addresses.

## How The Plaintext Workflow Works

The top-level command is:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem scripts/run_plaintext_workflow.sh
```

The workflow performs these stages:

1. `export_tf_outputs.sh` writes Terraform outputs into `.orchestration/terraform-output.json`.
2. `build_inventory.sh` converts Terraform outputs into `.orchestration/inventory.env`.
3. `build_cluster_metadata.sh` creates private Kafka bootstrap and KRaft quorum metadata in `.orchestration/cluster.env`.
4. `prepare_benchmark_client.sh` installs Java, Kafka tooling, client config, and the benchmark runner on the benchmark EC2 instance.
5. `bootstrap_brokers.sh` installs Kafka, renders broker config, formats KRaft storage, starts Kafka with `systemd`, and checks Kafka API readiness.
6. `run_parameter_sweep.sh` reads a sweep config, runs all values and trials, copies raw outputs back locally, parses each run, aggregates the sweep, and exports tables/plots.

The deployment part is checkpointed, so interrupted deployment steps can be resumed. Benchmark runs create new run directories.

## Parameter Sweep Configuration

Baseline configuration lives in:

- `config/baselines/plaintext-default.json`

Sweep configurations live in:

- `config/sweeps/message_size_bytes.json`
- `config/sweeps/target_messages_per_second.json`
- `config/sweeps/security_mode.json`

The currently validated full plaintext sweep is:

```json
{
  "name": "message-size-bytes",
  "baseline": "plaintext-default",
  "variable": "message_size_bytes",
  "trials": 3,
  "values": [1024, 10240, 102400]
}
```

This means the framework runs three trials for each message size while holding all other baseline settings fixed.

## Result Outputs

Each benchmark run produces a directory containing:

- `producer-perf.log`: raw Kafka `kafka-producer-perf-test.sh` output.
- `topic-create.log`: topic creation output.
- `topic-delete.log`: topic deletion output, when cleanup is enabled.
- `metadata.json`: run configuration and context.
- `result.json`: parsed structured metrics for that run.

Each completed sweep produces:

- `summary.json`: full structured sweep summary.
- `summary.csv`: flat tabular summary.
- `export/table.csv`: dissertation-ready table data.
- `export/table.tex`: LaTeX table.
- `export/throughput_records_per_sec.svg`: throughput plot.
- `export/throughput_mb_per_sec.svg`: throughput-by-MB plot.
- `export/avg_latency_ms.svg`: average latency plot.
- `export/max_latency_ms.svg`: max latency plot.

The latest valid full plaintext result set is:

```text
results/plaintext-full-fixed/message-size-bytes/
```

Use this directory rather than the earlier partial run under:

```text
results/plaintext-full/message-size-bytes/
```

The earlier `plaintext-full` run was interrupted by broker disk exhaustion during the first `102400` byte trial. The fixed run increased EC2 root volumes and added per-run topic cleanup.

## Latest Plaintext Results

The completed fixed sweep contains 9 runs:

- 3 message sizes: `1024`, `10240`, `102400` bytes.
- 3 trials per message size.
- 3 brokers.
- replication factor `3`.
- 6 partitions.
- 100,000 records per run.
- target throughput `1000 records/s`.
- security mode `plaintext`.

Grouped mean results:

| Message size bytes | Throughput records/s | Throughput MB/s | Avg latency ms | Max latency ms |
|---:|---:|---:|---:|---:|
| 1024 | 999.79 | 0.98 | 5.63 | 600.67 |
| 10240 | 999.73 | 9.76 | 4.55 | 529.33 |
| 102400 | 999.68 | 97.62 | 24.73 | 1463.00 |

The structured source for these values is:

```text
results/plaintext-full-fixed/message-size-bytes/summary.json
```

## Fault Tolerance And Idempotency

Current hardening features:

- Deployment checkpoint file support.
- Atomic local state writes using temporary files and `mv`.
- Retry wrappers around remote operations.
- Kafka `systemd` service checks.
- Kafka API readiness checks, not just process checks.
- Broker/client use private Kafka addresses and public SSH addresses.
- Benchmark result directories are made readable after `sudo` execution.
- Remote producer runs use unique topics.
- Topics are deleted after each run to prevent retained benchmark data from filling broker disks.
- EC2 root volumes are configured as 40 GB `gp3` volumes.

## Important Cost Note

The AWS resources created by Terraform continue to cost money while running. When the environment is no longer needed, destroy it from:

```bash
terraform -chdir=infrastructure/terraform/envs/dev destroy
```

Do not destroy the environment if you still need to inspect live broker state or rerun experiments.

## Documentation Map

Detailed supporting documentation:

- `docs/architecture.md`: architecture, components, and execution flow.
- `docs/experiment-methodology.md`: benchmarking method and validity controls.
- `docs/experiment-matrix.md`: experiment dimensions and planned comparisons.
- `docs/industry-kafka-setups.md`: source-derived industry Kafka setup evidence and practical benchmark profiles.
- `docs/sweep-framework.md`: parameter sweep design.
- `docs/export-layer.md`: tables and plot export process.
- `docs/reproducibility.md`: rerun and environment guidance.
- `docs/thesis-mapping.md`: mapping from artefact to dissertation chapters/rubric.
- `docs/deployment-hardening.md`: fault tolerance and idempotency notes.
- `deploy/kafka/README.md`: Kafka bootstrap and config scripts.
- `scripts/orchestration/README.md`: orchestration script responsibilities.
- `infrastructure/terraform/README.md`: Terraform infrastructure design.

## Next Development Steps

1. Add TLS deployment mode.
2. Add mTLS deployment mode.
3. Run equivalent sweeps for plaintext, TLS, and mTLS.
4. Add comparison exports across security modes.
5. Add host-level metrics if time allows.
