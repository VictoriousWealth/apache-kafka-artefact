# Kafka Security Benchmarking Artefact

This repository contains the dissertation artefact for measuring Apache Kafka performance under controlled security and workload configurations. The current implemented path provisions an AWS EC2 Kafka cluster, deploys plaintext, TLS, or mTLS Kafka modes, runs parameter sweeps and factorial benchmark plans, parses raw Kafka benchmark output into structured metrics, and exports dissertation-ready tables and plots.

The long-term artefact goal is:

> A configurable Kafka benchmarking framework that supports controlled parameter sweeps and selected factorial experiments over security and deployment variables, with primary emphasis on quantifying throughput and latency overhead under plaintext, TLS, and mTLS configurations.

## Current Status

Implemented:

- AWS infrastructure provisioning with Terraform.
- Three-broker and five-broker Kafka KRaft cluster phases on EC2.
- One EC2 benchmark client.
- Plaintext Kafka deployment and readiness checks.
- TLS Kafka deployment and readiness checks.
- mTLS Kafka deployment, client-certificate authentication, and readiness checks.
- Parameter sweep execution from JSON configuration.
- Factorial plan generation and resumable execution from JSONL configuration.
- Broker-count phase preparation for correct 3-broker and 5-broker experiments.
- Kafka producer performance benchmark execution.
- Targeted Kafka consumer performance benchmark runner and parser.
- Consumer-side security slice plan and resumable execution through the factorial executor.
- Concurrent producer execution for `producer_count > 1`.
- Per-run host telemetry capture for benchmark client and active brokers.
- Raw result parsing into `result.json`.
- Sweep-level aggregation into `summary.json` and `summary.csv`.
- Dissertation export layer producing CSV, LaTeX, and SVG plots.

Not implemented yet:

- Certificate rotation workflow.
- Full factorial consumer-side workload campaign. The implemented consumer path is a targeted validation slice.

## Research Goal

The primary dissertation question is:

> What is the performance overhead introduced by zero-trust-inspired security mechanisms, particularly mTLS, in high-throughput Kafka-based distributed systems?

The artefact supports that question by creating repeatable Kafka deployments and running controlled synthetic workloads. Early validation used one-factor-at-a-time sweeps; the current plaintext evaluation also supports factorial benchmark plans.

## System Overview

The system has five main layers:

- `infrastructure/terraform/`: provisions the AWS VPC, subnet, security groups, Kafka broker EC2 instances, and benchmark client EC2 instance.
- `deploy/kafka/`: contains Kafka installation scripts, broker configuration templates, client configuration, and the producer benchmark runner.
- `config/baselines/`: defines fixed baseline experiment settings.
- `config/sweeps/`: defines parameter ranges to test, for example message size or target throughput.
- `config/factorials/`: defines larger factorial experiment spaces.
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
        +-- kafka-broker-4
        +-- kafka-broker-5
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

For the reduced final security-overhead campaign, generate the plan with:

```bash
scripts/orchestration/generate_factorial_plan.sh \
  config/factorials/security-overhead-final.json \
  .orchestration/security-overhead-final-plan.jsonl
```

The current executor implements plaintext, TLS, and mTLS execution. A plaintext five-broker phase can be run with:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
FACTORIAL_PLAN_FILE=.orchestration/security-overhead-final-plan.jsonl \
SECURITY_MODE_FILTER=plaintext \
BROKER_COUNT_FILTER=5 \
LOCAL_RESULTS_DIR=results/factorial-final \
RESULT_SET_NAME=security-overhead-final-plaintext-broker5 \
CHECKPOINT_FILE=.orchestration/security-overhead-final-plaintext-broker5.checkpoint \
scripts/orchestration/run_factorial_plan.sh
```

The factorial executor is resumable and records `started.jsonl`, `completed.jsonl`, `failures.jsonl` when failures occur, and a checkpoint file under `.orchestration/`.

TLS deployment is handled by:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
scripts/orchestration/deploy_tls_cluster.sh
```

TLS and mTLS use broker data traffic on `9094`. mTLS deployment is handled by:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
scripts/orchestration/deploy_mtls_cluster.sh
```

The current live AWS cluster was last deployed in mTLS mode, so run plaintext or TLS phases only after redeploying the matching cluster mode.

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

The reduced final security-overhead factorial campaign is documented in:

```text
docs/experiment-matrix.md
config/factorials/security-overhead-final.json
.orchestration/security-overhead-final-plan.jsonl
```

The generated final campaign contains `5,184` runs after Kafka validity constraints are applied:

- `1,728` plaintext runs.
- `1,728` TLS runs.
- `1,728` mTLS runs.

The older plaintext-only requested matrix is retained in `docs/plaintext-factorial-config.md` and `config/factorials/plaintext-requested-full.json` as historical design context.

## Result Outputs

Each benchmark run produces a directory containing:

- `producer-perf.log`: raw Kafka `kafka-producer-perf-test.sh` output.
- `consumer-perf.log`: raw Kafka `kafka-consumer-perf-test.sh` output for targeted consumer benchmark runs.
- `host-telemetry/*.jsonl`: raw per-host CPU, memory, network, and disk telemetry samples when telemetry is enabled.
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

Telemetry-enabled summaries include columns for `telemetry_host_count`, benchmark-client mean CPU, broker mean CPU, and broker max-CPU mean.

The enriched measurement schema also includes:

- producer spread metrics: observed producer count, min/max producer throughput, and min/max producer average latency.
- interval-derived latency diagnostics: p95/p99 of Kafka producer interval average latency and interval max latency.
- memory telemetry: benchmark-client and broker mean memory-used percentage.
- network telemetry: benchmark-client RX/TX deltas and broker RX/TX mean/total deltas.
- disk telemetry: benchmark-client and broker read/write sector deltas.
- reliability counters in `summary.json`: `started_count`, `completed_count`, and `failure_count`.

The interval p95/p99 fields are not true per-record latency percentiles. They are derived from Kafka producer-perf interval summary lines and should be reported as interval-level diagnostics.

Targeted consumer benchmark runs use `run_consumer_perf.sh`. They seed a topic with Kafka producer-perf, consume it with Kafka consumer-perf, and parse records consumed, MB/s, records/s, rebalance time, and fetch time. This path is intended for a smaller consumer-side slice rather than the full producer factorial campaign.

The targeted consumer-side security slice is defined in:

```text
config/factorials/consumer-security-slice.json
.orchestration/consumer-security-slice-plan.jsonl
```

It contains 72 planned runs across plaintext, TLS, and mTLS.

Matched security-mode comparison exports produce:

- `comparison.csv`: joined plaintext/TLS/mTLS rows by identical workload and deployment configuration.
- `summary.csv`: mean TLS and mTLS percentage changes relative to plaintext.
- `table.tex`: LaTeX summary table for dissertation use.
- `throughput_overhead_pct.svg`: throughput change plot.
- `avg_latency_overhead_pct.svg`: average-latency change plot.
- `max_latency_overhead_pct.svg`: max-latency change plot.
- `interval_avg_latency_p95_overhead_pct.svg`: interval average-latency p95 change plot.
- `interval_avg_latency_p99_overhead_pct.svg`: interval average-latency p99 change plot.
- `client_cpu_overhead_pct.svg`: benchmark-client CPU change plot.
- `broker_cpu_overhead_pct.svg`: broker CPU change plot.
- `client_network_tx_overhead_pct.svg`: benchmark-client network transmit change plot.
- `broker_network_rx_overhead_pct.svg`: broker network receive change plot.
- `broker_disk_write_overhead_pct.svg`: broker disk write-sector change plot.

For canonical final campaign result names, comparison export can be run with:

```bash
scripts/analysis/export_final_phase_comparison.sh --broker-count 5
scripts/analysis/export_final_phase_comparison.sh --broker-count 3
```

The latest completed full one-factor plaintext sweep result set is historical validation data:

```text
results/plaintext-full-fixed/message-size-bytes/
```

Use this directory rather than the earlier partial run under:

```text
results/plaintext-full/message-size-bytes/
```

The earlier `plaintext-full` run was interrupted by broker disk exhaustion during the first `102400` byte trial. The fixed run increased EC2 root volumes and added per-run topic cleanup.

These one-factor plaintext sweep results are useful for showing early pipeline validation and message-size sensitivity. They are not part of the final matched plaintext/TLS/mTLS factorial campaign.

## Historical Plaintext Validation Results

The older plaintext factorial validation result set is:

```text
results/factorial/plaintext-requested-full-broker5/
```

Current state of this result set:

- 100 completed 5-broker plaintext factorial runs.
- 0 recorded failures.
- 100 local `result.json` files.
- no host telemetry, because these runs were executed before the telemetry-enabled final pipeline was implemented.
- 5 brokers.
- replication factor `3`.
- min in-sync replicas `3`.
- 6 partitions.
- 1,024 byte messages.
- target throughput `1000 records/s`.
- varied so far: `batch_size`, `acks`, `producer_count`, and `compression_type`.

Observed summary across the first 100 runs:

| Metric | Value |
|---|---:|
| Total records sent | 10,000,000 |
| Mean throughput records/s | 999.55 |
| Min throughput records/s | 998.35 |
| Max throughput records/s | 999.80 |
| Mean avg latency ms | 24.18 |
| Min avg latency ms | 3.77 |
| Max avg latency ms | 81.55 |
| Max observed max latency ms | 7950.00 |

Interpretation: this is a historical pipeline validation and partial plaintext baseline. It shows stable throughput near the 1000 records/s target, while latency increases materially as producer concurrency rises from 1 to 6 and 12 producers. It must not be used for final security-overhead conclusions because it lacks host telemetry, uses the older plaintext-only campaign design, and is not matched against TLS/mTLS final-campaign rows.

Final dissertation security-overhead comparisons should use only telemetry-enabled matched rows under:

```text
results/factorial-final/
```

## Latest TLS Validation

The first TLS smoke result set is:

```text
results/tls-smoke/tls-broker5-smoke/
```

Validated configuration:

- 5 brokers.
- TLS broker listener on `9094`.
- replication factor `3`.
- min in-sync replicas `3`.
- 6 partitions.
- 1,024 byte messages.
- target throughput `1000 records/s`.
- `batch_size=16384`.
- `acks=1`.
- `producer_count=1`.
- `compression_type=none`.
- host telemetry from benchmark client plus all five brokers.

Smoke result:

| Metric | Value |
|---|---:|
| Records sent | 100,000 |
| Throughput records/s | 999.75 |
| Throughput MB/s | 0.98 |
| Avg latency ms | 6.96 |
| Max latency ms | 1024.00 |
| Telemetry host count | 6 |
| Benchmark client mean CPU % | 12.30 |
| Broker mean CPU % | 12.41 |
| Broker max-CPU mean % | 53.99 |

## Latest mTLS Validation

The first mTLS smoke result set is:

```text
results/mtls-smoke/mtls-broker5-smoke/
```

Validated configuration:

- 5 brokers.
- mTLS broker listener on `9094`.
- client-certificate authentication required.
- replication factor `3`.
- min in-sync replicas `3`.
- 6 partitions.
- 1,024 byte messages.
- target throughput `1000 records/s`.
- `batch_size=16384`.
- `acks=1`.
- `producer_count=1`.
- `compression_type=none`.
- host telemetry from benchmark client plus all five brokers.

Smoke result:

| Metric | Value |
|---|---:|
| Records sent | 100,000 |
| Throughput records/s | 999.60 |
| Throughput MB/s | 0.98 |
| Avg latency ms | 8.63 |
| Max latency ms | 1173.00 |
| Telemetry host count | 6 |
| Benchmark client mean CPU % | 12.56 |
| Broker mean CPU % | 12.22 |
| Broker max-CPU mean % | 47.85 |

## Current Final Campaign State

The first resumable final-campaign batch has been started for:

```text
results/factorial-final/security-overhead-final-mtls-broker5/
```

Current state:

- 25 completed mTLS five-broker final-campaign runs.
- 0 recorded failures.
- 25 checkpoint entries in `.orchestration/security-overhead-final-mtls-broker5.checkpoint`.
- 25 local `result.json` files.
- Broker count `5`.
- replication factor `3`.
- min in-sync replicas `3`.
- 6 partitions.
- 1,024 byte messages.
- target throughput `1000 records/s`.
- covered so far: `acks=1`, part of `acks=all`, `producer_count` values `1`, `6`, and `12`, and both `none` and `lz4` compression.

Observed summary across the first 25 mTLS final-campaign rows:

| Metric | Value |
|---|---:|
| Mean throughput records/s | 999.377 |
| Min throughput records/s | 998.083 |
| Max throughput records/s | 999.760 |
| Mean avg latency ms | 241.836 |
| Min avg latency ms | 7.060 |
| Max avg latency ms | 852.510 |
| Mean max latency ms | 6884.840 |
| Max observed max latency ms | 18790.000 |
| Mean benchmark-client CPU % | 44.887 |
| Mean broker CPU % | 7.892 |

This is an in-progress partial final-campaign result set. It is suitable for checking pipeline stability and early trends, but final dissertation claims should use matched plaintext/TLS/mTLS rows across the intended campaign slices.

## Latest Security Comparison Smoke

The first matched plaintext/TLS/mTLS smoke comparison is:

```text
results/security-comparison-smoke/
```

This comparison joins the same five-broker workload row across all three security modes:

- 5 brokers.
- replication factor `3`.
- min in-sync replicas `3`.
- 6 partitions.
- 1,024 byte messages.
- target throughput `1000 records/s`.
- `batch_size=16384`.
- `acks=1`.
- `producer_count=1`.
- `compression_type=none`.
- trial `1`.

Mean percentage change relative to plaintext:

| Security mode | Throughput % | Avg latency % | Max latency % | Client CPU % | Broker CPU % |
|---|---:|---:|---:|---:|---:|
| TLS | -0.002 | 71.852 | 105.622 | 27.026 | 191.916 |
| mTLS | -0.017 | 113.086 | 135.542 | 29.673 | 187.468 |

This is a smoke comparison only. It validates the comparison pipeline, but final dissertation conclusions should use larger matched result sets.

## Latest Consumer Benchmark Validation

The first validated mTLS consumer smoke result set is:

```text
results/consumer-slice/consumer-security-slice-mtls-broker5-smoke-fixed3/
```

Validated configuration:

- benchmark type `consumer`.
- 5 brokers.
- mTLS broker listener on `9094`.
- replication factor `3`.
- min in-sync replicas `3`.
- 6 partitions.
- 1,024 byte messages.
- 100,000 records.
- seed producer target throughput `1000 records/s`.
- `consumer_count=1`.
- `compression_type=none`.
- host telemetry from benchmark client plus all five brokers.

Smoke result:

| Metric | Value |
|---|---:|
| Records consumed | 100,000 |
| Consumer throughput records/s | 27,292.576 |
| Consumer throughput MB/s | 26.653 |
| Data consumed MB | 97.656 |
| Rebalance time ms | 1072 |
| Fetch time ms | 2592 |
| Telemetry host count | 6 |
| Benchmark client mean CPU % | 17.667 |
| Broker mean CPU % | 5.688 |

The earlier completed fixed one-factor message-size sweep contains 9 runs:

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
- Factorial runs use deterministic run IDs and checkpoint/resume state.
- Remote result copying uses temporary local directories before marking runs complete.
- Per-run host telemetry is started before the benchmark process and stopped before result parsing.
- Telemetry raw samples are retained as JSONL so parsed summaries remain auditable.

## Important Cost Note

The AWS resources created by Terraform continue to cost money while running. When the environment is no longer needed, destroy it from:

```bash
terraform -chdir=infrastructure/terraform/envs/dev destroy
```

Do not destroy the environment if you still need to inspect live broker state or rerun experiments.

## Documentation Map

Detailed supporting documentation:

- `docs/architecture.md`: architecture, components, and execution flow.
- `docs/consumer-benchmarking.md`: targeted consumer-side benchmark design, execution, and validation.
- `docs/experiment-methodology.md`: benchmarking method and validity controls.
- `docs/experiment-matrix.md`: experiment dimensions and planned comparisons.
- `docs/final-campaign-operating-notes.md`: phase order, batching, checkpoint, cost, and safety guidance for the final campaign.
- `docs/industry-kafka-setups.md`: source-derived industry Kafka setup evidence and practical benchmark profiles.
- `docs/sweep-framework.md`: parameter sweep design.
- `docs/export-layer.md`: tables and plot export process.
- `docs/result-schema.md`: result files, metric definitions, telemetry fields, and comparison schema.
- `docs/reproducibility.md`: rerun and environment guidance.
- `docs/thesis-mapping.md`: mapping from artefact to dissertation chapters/rubric.
- `docs/deployment-hardening.md`: fault tolerance and idempotency notes.
- `deploy/kafka/README.md`: Kafka bootstrap and config scripts.
- `scripts/orchestration/README.md`: orchestration script responsibilities.
- `infrastructure/terraform/README.md`: Terraform infrastructure design.

## Next Development Steps

1. Run larger matched plaintext, TLS, and mTLS final-campaign phases.
2. Use the comparison export for each completed phase.
3. Add cross-phase comparison for broker-count 3 vs 5.
4. Run the targeted consumer-side slice across plaintext, TLS, and mTLS.
5. Add certificate rotation measurement if time allows.
