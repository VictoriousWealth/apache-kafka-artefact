# Consumer Benchmarking

## Purpose

Consumer benchmarking is now in scope as a targeted validation slice. It complements the main producer-side final campaign by measuring whether TLS and mTLS also affect Kafka read-path performance, especially when consumers fetch compressed or larger records.

The consumer slice is intentionally smaller than the producer final campaign. It is not a full consumer factorial campaign because that would substantially increase runtime and AWS cost without being necessary for the primary write-path security-overhead question.

## Consumer Slice Config

Machine-readable config:

```text
config/factorials/consumer-security-slice.json
```

Generated plan:

```text
.orchestration/consumer-security-slice-plan.jsonl
```

Generate or refresh the plan with:

```bash
scripts/orchestration/generate_factorial_plan.sh \
  config/factorials/consumer-security-slice.json \
  .orchestration/consumer-security-slice-plan.jsonl
```

Expected plan size:

```text
72 runs
```

## Parameter Values

| Parameter | Values |
|---|---|
| `benchmark_type` | `consumer` |
| `security_mode` | `plaintext`, `tls`, `mtls` |
| `broker_count` | `5` |
| `replication_factor` | `3` |
| `min_insync_replicas` | `3` |
| `partition_count` | `6` |
| `message_size_bytes` | `1024`, `102400` |
| `target_messages_per_second` | `1000` |
| `batch_size` | `16384` |
| `acks` | `all` |
| `producer_count` | `1` |
| `consumer_count` | `1`, `6` |
| `compression_type` | `none`, `lz4` |
| `trials` | `3` |

Run count:

```text
3 security modes x 2 message sizes x 2 consumer counts x 2 compression modes x 3 trials = 72 runs
```

## Execution Model

The consumer runner performs three stages:

1. Create a unique benchmark topic.
2. Seed the topic with `kafka-producer-perf-test.sh`.
3. Consume the records with `kafka-consumer-perf-test.sh`.

The runner writes:

```text
producer-seed.log
consumer-perf.log
metadata.json
topic-create.log
topic-delete.log
host-telemetry/*.jsonl
result.json
```

The parser extracts:

| Metric | Meaning |
|---|---|
| `records_consumed` | Number of records consumed. |
| `throughput_records_per_sec` | Consumer throughput in records/sec. |
| `throughput_mb_per_sec` | Consumer throughput in MB/sec. |
| `data_consumed_mb` | MB consumed by consumer-perf. |
| `rebalance_time_ms` | Consumer group rebalance time. |
| `fetch_time_ms` | Consumer fetch time. |
| telemetry fields | Same CPU, memory, network, and disk telemetry schema as producer runs. |

## Running A Phase

The consumer slice uses the same executor as the producer campaign:

```bash
scripts/orchestration/run_factorial_plan.sh
```

Example mTLS broker-5 consumer batch:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
FACTORIAL_PLAN_FILE=.orchestration/consumer-security-slice-plan.jsonl \
SECURITY_MODE_FILTER=mtls \
BROKER_COUNT_FILTER=5 \
MAX_RUNS=10 \
LOCAL_RESULTS_DIR=results/consumer-slice \
RESULT_SET_NAME=consumer-security-slice-mtls-broker5 \
CHECKPOINT_FILE=.orchestration/consumer-security-slice-mtls-broker5.checkpoint \
AGGREGATE_RESULTS=true \
EXPORT_RESULTS=false \
scripts/orchestration/run_factorial_plan.sh
```

Equivalent canonical result-set names:

```text
results/consumer-slice/consumer-security-slice-plaintext-broker5/
results/consumer-slice/consumer-security-slice-tls-broker5/
results/consumer-slice/consumer-security-slice-mtls-broker5/
```

Equivalent checkpoints:

```text
.orchestration/consumer-security-slice-plaintext-broker5.checkpoint
.orchestration/consumer-security-slice-tls-broker5.checkpoint
.orchestration/consumer-security-slice-mtls-broker5.checkpoint
```

## Comparison Export

After all three security modes have matching consumer summaries, run:

```bash
scripts/analysis/export_consumer_slice_comparison.sh
```

This writes to:

```text
results/consumer-slice/consumer-security-slice-broker5-comparison/
```

The comparison exporter joins rows by workload and deployment fields, including `benchmark_type`, so consumer rows are not mixed with producer rows.

## Current Validation

A live mTLS consumer smoke validation has completed successfully:

```text
results/consumer-slice/consumer-security-slice-mtls-broker5-smoke-fixed3/
```

Validated row:

```text
consumer-security-slice-mtls-b5-rf3-isr3-msg1024-tps1000-batch16384-acksall-prod1-cons1-compnone-trial1
```

Observed metrics:

| Metric | Value |
|---|---:|
| Records consumed | 100,000 |
| Consumer throughput records/s | 27,292.576 |
| Consumer throughput MB/s | 26.653 |
| Data consumed MB | 97.656 |
| Rebalance time ms | 1,072 |
| Fetch time ms | 2,592 |
| Telemetry host count | 6 |
| Benchmark client mean CPU % | 17.667 |
| Broker mean CPU % | 5.688 |

Earlier failed consumer smoke attempts are retained as engineering debugging artefacts only. Use the `smoke-fixed3` result as the validated consumer-path smoke result.

## Dissertation Interpretation

The consumer slice should be reported as a targeted read-path validation. It can support claims such as:

- whether secure transport affects consumer fetch throughput;
- whether mTLS shifts CPU cost onto the consumer/client host;
- whether compression changes the read-path overhead under secure modes;
- whether larger records change consumer-side security overhead.

It should not be presented as equivalent in scope to the 5,184-run producer final campaign.
