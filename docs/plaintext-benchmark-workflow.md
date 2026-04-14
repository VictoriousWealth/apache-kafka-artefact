# Plaintext Benchmark Workflow

## Goal

This workflow defines the first runnable benchmark path for the artefact: a plaintext producer performance run against the EC2 Kafka cluster.

## Sequence

1. Provision infrastructure with Terraform.
2. Run `scripts/orchestration/deploy_plaintext_cluster.sh`.
3. Run `scripts/orchestration/run_plaintext_producer_baseline.sh`.
4. Inspect the copied results under `results/plaintext/`.

## Current Benchmark Shape

The first benchmark path uses Kafka's `kafka-producer-perf-test.sh` from the benchmark client host.

It performs:

- idempotent topic creation if the topic does not already exist
- a producer throughput run against the plaintext brokers
- local result metadata capture on the benchmark client
- result copy-back to the local repository

## Current Outputs

For each run, the result directory contains:

- `producer-perf.log`
- `topic-create.log`
- `metadata.json`

## Scope Boundary

This first path measures producer-side throughput only. It is intended to validate the end-to-end benchmark flow before adding:

- consumer-side measurement
- latency parsing and summarisation
- TLS and mTLS variants
- scenario-driven automation
