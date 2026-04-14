# Plaintext Benchmark Workflow

## Goal

This workflow defines the first runnable benchmark path for the artefact: a plaintext producer performance sweep against the EC2 Kafka cluster.

## Sequence

1. Provision infrastructure with Terraform.
2. Run `scripts/orchestration/deploy_plaintext_cluster.sh`.
3. Run `scripts/orchestration/run_parameter_sweep.sh`.
4. Inspect the copied results under `results/plaintext/`.

## Current Benchmark Shape

The first benchmark path uses Kafka's `kafka-producer-perf-test.sh` from the benchmark client host.

It performs:

- baseline lookup from `config/baselines/...`
- sweep lookup from `config/sweeps/...`
- idempotent topic creation if the topic does not already exist
- a producer throughput run against the plaintext brokers
- local result metadata capture on the benchmark client
- result copy-back to the local repository
- parsing into a standard `result.json` schema
- sweep-level aggregation into `summary.json` and `summary.csv`

## Current Outputs

For each run, the result directory contains:

- `producer-perf.log`
- `topic-create.log`
- `metadata.json`
- `result.json`

At the sweep directory level, the framework also writes:

- `summary.json`
- `summary.csv`

## Structured Result Schema

The standard result schema currently captures:

- `run_id`
- `security_mode`
- `baseline_name`
- `sweep_name`
- `sweep_variable`
- `sweep_value`
- cluster configuration
- resolved run configuration
- throughput metrics
- average and maximum latency if present in the raw Kafka output

The sweep summary outputs provide a flat comparison view across all resolved runs in the sweep.

## Scope Boundary

This first path measures producer-side throughput only. It is intended to validate the end-to-end benchmark flow before adding:

- consumer-side measurement
- latency parsing and summarisation
- TLS and mTLS variants
- broader sweep automation
