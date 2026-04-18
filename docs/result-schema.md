# Result Schema

## Purpose

This document defines the result files and metric fields produced by the Kafka security benchmarking artefact. It is intended to make dissertation tables, plots, and overhead calculations traceable back to raw benchmark outputs.

The schema applies primarily to producer factorial runs executed through:

```bash
scripts/orchestration/run_factorial_plan.sh
```

Targeted consumer benchmark runs use a smaller related schema documented near the end of this file.

## Per-Run Files

Each producer benchmark run directory contains:

| File | Description |
|---|---|
| `metadata.json` | Workload, cluster, security mode, and run configuration written before parsing. |
| `producer-perf.log` | Combined raw output from all producer-perf processes. |
| `producer-perf-N.log` | Raw output from producer `N` when `producer_count > 1`. |
| `topic-create.log` | Kafka topic creation output. |
| `topic-delete.log` | Kafka topic deletion output when cleanup is enabled. |
| `host-telemetry/*.jsonl` | Per-host CPU, memory, network, and disk samples captured during the run. |
| `result.json` | Structured parsed result for one run. |

Consumer benchmark run directories contain:

| File | Description |
|---|---|
| `metadata.json` | Consumer workload, cluster, security mode, and run configuration. |
| `producer-seed.log` | Producer-perf output used to seed records before consumption. |
| `consumer-perf.log` | Raw Kafka consumer-perf output. |
| `result.json` | Structured parsed consumer result. |

## Sweep And Phase Files

Each result-set directory contains:

| File | Description |
|---|---|
| `started.jsonl` | One JSON line for each run attempted by the factorial executor. |
| `completed.jsonl` | One JSON line for each run completed and copied locally. |
| `failures.jsonl` | One JSON line for each failed run, when failures occur. |
| `summary.json` | Aggregated structured summary for all local `result.json` files. |
| `summary.csv` | Flat tabular summary used by analysis and dissertation exports. |

The matching checkpoint file is stored under `.orchestration/` and is used for resumability. Checkpoints are operational state rather than dissertation data.

## Core Run Identity

These fields identify the run and should be retained in all exports:

| Field | Source | Meaning |
|---|---|---|
| `run_id` | Generated plan | Deterministic logical run identifier. |
| `security_mode` | Plan/metadata | `plaintext`, `tls`, or `mtls`. |
| `baseline_name` | Plan/metadata | Baseline or campaign name. |
| `sweep_name` | Plan/metadata | Sweep or factorial campaign name. |
| `sweep_variable` | Plan/metadata | Variable name for one-factor sweeps; `factorial_config` for factorial rows. |
| `sweep_value` | Plan/metadata | Sweep value or factorial run ID. |
| `trial_index` | Plan/metadata | Trial number for repeated configurations. |
| `trial_count` | Plan/metadata | Number of planned trials for the same configuration. |

`run_id` differs across security modes because the security mode is embedded in the name. Security-overhead comparisons therefore join rows by workload and deployment fields, not by `run_id`.

## Workload And Deployment Metadata

These fields describe the Kafka deployment and workload configuration:

| Field | Meaning |
|---|---|
| `broker_count` | Number of active Kafka brokers in the phase. |
| `partitions` | Topic partition count. |
| `replication_factor` | Topic replication factor. |
| `min_insync_replicas` | Topic-level minimum in-sync replica requirement. |
| `num_records` | Number of records requested for the run. |
| `record_size_bytes` | Producer record size in bytes. |
| `throughput_limit_records_per_sec` | Target producer throughput. |
| `producer_count` | Number of concurrent producer-perf processes. |
| `consumer_count` | Consumer count metadata; producer factorial runs currently use `1`. |
| `batch_size` | Producer `batch.size`. |
| `linger_ms` | Producer `linger.ms`. |
| `acks` | Producer acknowledgement mode, for example `1` or `all`. |
| `compression_type` | Producer compression mode, for example `none` or `lz4`. |

These fields are required for fair comparison because changing any of them can affect throughput, latency, durability, or resource usage.

## Producer Performance Metrics

These metrics are parsed from Kafka `kafka-producer-perf-test.sh` output.

| Field | Type | Meaning |
|---|---|---|
| `records_sent` | Raw/derived | Total records reported sent across all producer processes. |
| `throughput_records_per_sec` | Derived | Sum of per-producer final throughput in records/sec. |
| `throughput_mb_per_sec` | Derived | Sum of per-producer final throughput in MB/sec. |
| `avg_latency_ms` | Derived | Record-weighted mean of per-producer final average latency. |
| `max_latency_ms` | Derived | Maximum final max-latency value across producer processes. |

For `producer_count=1`, these values correspond directly to the final producer-perf summary line.

For `producer_count>1`, each producer writes its own `producer-perf-N.log`; the parser combines them into a single run-level result.

## Producer Spread Metrics

These fields check whether a concurrent producer run is balanced or whether one producer is much slower than the others.

| Field | Meaning |
|---|---|
| `producer_count_observed` | Number of producer final summaries parsed. |
| `producer_throughput_records_per_sec_min` | Lowest final producer throughput. |
| `producer_throughput_records_per_sec_max` | Highest final producer throughput. |
| `producer_avg_latency_ms_min` | Lowest final producer average latency. |
| `producer_avg_latency_ms_max` | Highest final producer average latency. |

These are important for interpreting runs where `producer_count` is `6` or `12`.

## Interval Latency Diagnostics

Kafka producer-perf prints periodic interval summary lines during a run. The parser uses those interval summaries to calculate diagnostic percentiles:

| Field | Meaning |
|---|---|
| `interval_summary_count` | Number of interval summary lines parsed across producer logs. |
| `interval_avg_latency_ms_p95` | p95 of interval average-latency values. |
| `interval_avg_latency_ms_p99` | p99 of interval average-latency values. |
| `interval_max_latency_ms_p95` | p95 of interval max-latency values. |
| `interval_max_latency_ms_p99` | p99 of interval max-latency values. |

These fields are **not true per-record latency percentiles**. They are interval-level diagnostics derived from producer-perf summary lines. They should be reported as diagnostic indicators of burstiness or transient latency behaviour, not as event-level p95/p99 latency.

## Host Telemetry Metrics

Host telemetry is sampled once per second while the benchmark run is active. The collector reads Linux `/proc` counters for CPU, memory, network, and disk.

Raw telemetry is stored as JSONL under:

```text
host-telemetry/
```

Each sample includes:

| Field | Meaning |
|---|---|
| `timestamp` | UTC timestamp for the sample. |
| `role` | `benchmark_client` or `broker`. |
| `host_id` | Logical host name such as `broker-1`. |
| `cpu_percent` | CPU utilisation percentage over the sample interval. |
| `memory_total_kb` | Host memory total. |
| `memory_used_kb` | Host memory used. |
| `memory_used_percent` | Host memory used percentage. |
| `network_rx_bytes` | Cumulative RX bytes across non-loopback interfaces. |
| `network_tx_bytes` | Cumulative TX bytes across non-loopback interfaces. |
| `disk_read_sectors` | Cumulative disk read sectors. |
| `disk_write_sectors` | Cumulative disk write sectors. |

## Flattened Telemetry Summary Fields

The parser summarises raw host telemetry into `result.json`, and the aggregator flattens the following fields into `summary.csv`:

| Field | Meaning |
|---|---|
| `telemetry_host_count` | Number of host telemetry JSONL files successfully parsed. |
| `benchmark_client_cpu_percent_mean` | Mean benchmark-client CPU utilisation. |
| `broker_cpu_percent_mean` | Mean of broker mean CPU utilisation values. |
| `broker_cpu_percent_max_mean` | Mean of broker max CPU utilisation values. |
| `benchmark_client_memory_used_percent_mean` | Mean benchmark-client memory used percentage. |
| `broker_memory_used_percent_mean` | Mean of broker memory used percentages. |
| `benchmark_client_network_rx_bytes_delta` | Client RX byte delta during the run. |
| `benchmark_client_network_tx_bytes_delta` | Client TX byte delta during the run. |
| `broker_network_rx_bytes_delta_mean` | Mean broker RX byte delta. |
| `broker_network_tx_bytes_delta_mean` | Mean broker TX byte delta. |
| `broker_network_rx_bytes_delta_total` | Sum of broker RX byte deltas. |
| `broker_network_tx_bytes_delta_total` | Sum of broker TX byte deltas. |
| `benchmark_client_disk_read_sectors_delta` | Client disk read sector delta. |
| `benchmark_client_disk_write_sectors_delta` | Client disk write sector delta. |
| `broker_disk_read_sectors_delta_mean` | Mean broker disk read sector delta. |
| `broker_disk_write_sectors_delta_mean` | Mean broker disk write sector delta. |
| `broker_disk_read_sectors_delta_total` | Sum of broker disk read sector deltas. |
| `broker_disk_write_sectors_delta_total` | Sum of broker disk write sector deltas. |

CPU is the most important telemetry metric for the dissertation because the theoretical model links cryptographic overhead to increased utilisation and latency growth.

Network and disk deltas are supporting metrics. They help distinguish cryptographic overhead from byte-volume, compression, replication, or storage effects.

## Reliability Fields

`summary.json` includes:

| Field | Meaning |
|---|---|
| `run_count` | Number of local `result.json` files included in the summary. |
| `started_count` | Number of started ledger entries, when `started.jsonl` exists. |
| `completed_count` | Number of completed ledger entries, when `completed.jsonl` exists. |
| `failure_count` | Number of failure ledger entries, when `failures.jsonl` exists. |

Failures and timeouts should be reported, not silently ignored. A high failure rate under a security mode is part of the system behaviour.

## Security Comparison Schema

The security comparison exporter consumes multiple `summary.csv` files and joins matched rows across modes.

Command:

```bash
scripts/analysis/export_security_comparison.sh \
  <output-dir> \
  <plaintext-summary.csv> \
  <tls-summary.csv> \
  <mtls-summary.csv>
```

Rows are matched by workload and deployment fields:

```text
broker_count
partitions
replication_factor
min_insync_replicas
num_records
record_size_bytes
throughput_limit_records_per_sec
producer_count
consumer_count
batch_size
linger_ms
acks
compression_type
trial_index
```

Percentage change is calculated as:

```text
(secure_mode_metric - plaintext_metric) / plaintext_metric * 100
```

For throughput, a negative value means lower throughput than plaintext. For latency, CPU, memory, network, and disk, a positive value means higher cost than plaintext.

## Consumer Result Schema

Targeted consumer benchmark runs are parsed by:

```bash
scripts/orchestration/parse_consumer_perf_results.sh <run-directory>
```

Consumer metrics include:

| Field | Meaning |
|---|---|
| `records_consumed` | Records consumed according to consumer-perf. |
| `throughput_records_per_sec` | Consumer throughput in records/sec. |
| `throughput_mb_per_sec` | Consumer throughput in MB/sec. |
| `data_consumed_mb` | Data consumed in MB. |
| `rebalance_time_ms` | Consumer group rebalance time. |
| `fetch_time_ms` | Fetch time reported by consumer-perf. |

Consumer benchmarking is intended as a targeted validation slice across plaintext, TLS, and mTLS. It is not currently part of the full producer factorial campaign.

## Dissertation Reporting Notes

Use these wording distinctions:

| Term | Correct interpretation |
|---|---|
| Throughput | Producer or consumer benchmark throughput, depending on benchmark type. |
| Average latency | Kafka producer-perf final average latency. |
| Max latency | Kafka producer-perf final maximum latency. |
| Interval p95/p99 | Diagnostic percentile over interval summaries, not true per-record percentile. |
| CPU overhead | Mean host CPU change relative to matched plaintext row. |
| Network/disk overhead | Counter deltas during the benchmark window, useful for explaining secondary effects. |
| Failure count | Number of failed planned runs in the phase ledger. |

For final dissertation claims, use matched plaintext/TLS/mTLS rows produced by the current telemetry-enabled pipeline. Older non-telemetry result sets should be described as historical validation only.
