# Plaintext Factorial Configuration

## Purpose

This document records the proposed plaintext-only experiment matrix before extending the same configuration space to TLS and mTLS. The aim is to preserve the full set of values under consideration while making the run count and Kafka validity constraints explicit.

This is the intended plaintext factorial sweep design. The current production runner still executes one-factor-at-a-time sweep files, so the full factorial design is represented as a separate machine-readable configuration until the factorial executor is added.

## Security Mode

The first execution phase is plaintext only:

```text
security_mode = plaintext
```

TLS and mTLS should reuse the same matrix only after the plaintext execution path is stable.

## Requested Parameter Values

Machine-readable config:

```text
config/factorials/plaintext-requested-full.json
```

| Parameter | Values |
|---|---|
| `broker_count` | `3`, `5` |
| `replication_factor` | `3`, `5` |
| `min_insync_replicas` | `3`, `4` |
| `message_size_bytes` | `1024`, `10240`, `102400` |
| `target_messages_per_second` | `1000`, `5000`, `10000` |
| `batch_size` | `16384`, `65536`, `131072` |
| `acks` | `1`, `all` |
| `producer_count` | `1`, `6`, `12` |
| `compression_type` | `none`, `lz4` |

## Kafka Validity Rules

Not every requested combination is valid Kafka configuration.

Required constraints:

```text
replication_factor <= broker_count
min_insync_replicas <= replication_factor
```

Invalid combinations from the requested values:

```text
broker_count=3, replication_factor=5
replication_factor=3, min_insync_replicas=4
```

Valid deployment/durability combinations:

| `broker_count` | `replication_factor` | `min_insync_replicas` |
|---:|---:|---:|
| 3 | 3 | 3 |
| 5 | 3 | 3 |
| 5 | 5 | 3 |
| 5 | 5 | 4 |

## Run Count

The valid deployment/durability space contains:

```text
4 combinations
```

The workload/producer space contains:

```text
message_size_bytes:         3
target_messages_per_second: 3
batch_size:                 3
acks:                       2
producer_count:             3
compression_type:           2
```

Workload/producer combinations:

```text
3 x 3 x 3 x 2 x 3 x 2 = 324
```

Valid plaintext logical conditions:

```text
4 x 324 = 1,296
```

With three repeated trials:

```text
1,296 x 3 = 3,888 plaintext runs
```

If the same matrix is later repeated for plaintext, TLS, and mTLS:

```text
3,888 x 3 = 11,664 total runs
```

## Execution Risk

This matrix is too large for a first plaintext execution pass.

At an estimated 2-5 minutes per run:

```text
3,888 plaintext runs = approximately 5.4 to 13.5 days continuous runtime
```

This excludes broker reprovisioning, retries, failed runs, result inspection, and cost from idle infrastructure while debugging.

## Execution Plan

Use the requested matrix as the full plaintext design space:

```text
config/factorials/plaintext-requested-full.json
```

Before running it end-to-end, generate a plan and verify the exact run count:

```bash
scripts/orchestration/generate_factorial_plan.sh \
  config/factorials/plaintext-requested-full.json \
  .orchestration/plaintext-requested-full-plan.jsonl
```

Expected output:

```text
3888 planned runs
```

Generated plan path:

```text
.orchestration/plaintext-requested-full-plan.jsonl
```

Each line is one concrete benchmark run configuration. The generated plan contains 972 runs for each valid deployment/durability combination.

The plan is executed with:

```text
scripts/orchestration/run_factorial_plan.sh
```

The executor provides deterministic run IDs, checkpoint/resume support, broker-count filtering, max-run limits for smoke testing, dry-run mode, failure logging, aggregation, and export.

Validated executor smoke run:

```text
results/factorial-smoke/executor-smoke/plaintext-requested-full-factorial-b5-rf3-isr3-msg1024-tps1000-batch16384-acks1-prod1-compnone-trial1/
```

Smoke result:

| Metric | Value |
|---|---:|
| Records sent | 100000 |
| Throughput records/s | 999.70 |
| Throughput MB/s | 0.98 |
| Avg latency ms | 4.22 |
| Max latency ms | 496.00 |

Current implementation status:

1. `broker_count=5` is provisioned in the dev AWS environment.
2. `producer_count=6` and `producer_count=12` are supported by launching concurrent `kafka-producer-perf-test.sh` processes.
3. The parser aggregates producer metrics by summing records/throughput, using a records-weighted average latency, and taking the maximum max-latency value.
4. `compression_type` and `min_insync_replicas` are wired into the plaintext benchmark path.

Current live broker addresses:

| Broker | Public IP | Private Kafka IP |
|---:|---|---|
| 1 | `18.135.104.81` | `10.20.1.69` |
| 2 | `13.135.128.31` | `10.20.1.238` |
| 3 | `13.40.69.184` | `10.20.1.91` |
| 4 | `35.178.239.59` | `10.20.1.118` |
| 5 | `13.40.173.156` | `10.20.1.53` |

The 5-broker KRaft cluster was bootstrapped fresh with:

```text
RESET_KAFKA_STORAGE=true
```

This reset remote Kafka broker log data only. Local benchmark results were not removed.

## Concurrent Producer Smoke Test

Direct smoke tests validated the new concurrent producer path using RF=5 on the five-broker cluster.

Six-producer smoke configuration:

```text
broker_count=5
replication_factor=5
min_insync_replicas=4
producer_count=6
message_size_bytes=1024
num_records=12000
target_messages_per_second=6000
acks=all
compression_type=none
```

Result directory:

```text
results/smoke/concurrent-producer-rf5/20260416T193230Z-plaintext-rf5-producers6-smoke/
```

Smoke result:

| Metric | Value |
|---|---:|
| Records sent | 12000 |
| Producer summaries aggregated | 6 |
| Throughput records/s | 3009.11 |
| Throughput MB/s | 2.95 |
| Avg latency ms | 261.15 |
| Max latency ms | 3935.00 |

Twelve-producer smoke configuration:

```text
broker_count=5
replication_factor=5
min_insync_replicas=4
producer_count=12
message_size_bytes=1024
num_records=12000
target_messages_per_second=12000
acks=all
compression_type=none
```

Result directory:

```text
results/smoke/concurrent-producer-rf5/20260416T194000Z-plaintext-rf5-producers12-smoke/
```

Smoke result:

| Metric | Value |
|---|---:|
| Records sent | 12000 |
| Producer summaries aggregated | 12 |
| Throughput records/s | 1504.56 |
| Throughput MB/s | 1.46 |
| Avg latency ms | 570.86 |
| Max latency ms | 7488.00 |

## Baseline Used For Early Validation

The following baseline is useful for smoke tests and partial validation, but it is not a replacement for the full requested factorial design:

Recommended stable baseline:

```json
{
  "security_mode": "plaintext",
  "broker_count": 3,
  "replication_factor": 3,
  "min_insync_replicas": 3,
  "partition_count": 6,
  "message_size_bytes": 10240,
  "target_messages_per_second": 5000,
  "batch_size": 65536,
  "acks": "all",
  "producer_count": 1,
  "compression_type": "none"
}
```

Early validation one-factor-at-a-time sweeps:

| Sweep | Values | Runs with 3 trials |
|---|---|---:|
| `message_size_bytes` | `1024`, `10240`, `102400` | 9 |
| `target_messages_per_second` | `1000`, `5000`, `10000` | 9 |
| `batch_size` | `16384`, `65536`, `131072` | 9 |
| `acks` | `1`, `all` | 6 |
| `producer_count` | `1`, `6`, `12` | 9 |
| `compression_type` | `none`, `lz4` | 6 |

Total first-pass one-factor-at-a-time plaintext runs:

```text
48 runs
```

These produce quick validation evidence while the full factorial executor is being implemented.

## Executable First-Pass Config Files

The first-pass executable baseline is:

```text
config/baselines/plaintext-requested-baseline.json
```

Executable one-factor-at-a-time sweep files:

```text
config/sweeps/plaintext-requested/message_size_bytes.json
config/sweeps/plaintext-requested/target_messages_per_second.json
config/sweeps/plaintext-requested/batch_size.json
config/sweeps/plaintext-requested/acks.json
config/sweeps/plaintext-requested/compression_type.json
config/sweeps/plaintext-requested/min_insync_replicas.json
```

Pending sweep:

```text
config/sweeps/plaintext-requested/producer_count.pending.json
```

The producer-count sweep is deliberately marked pending because the current benchmark runner does not yet launch multiple producer processes. Recording `producer_count=6` or `producer_count=12` without actually running concurrent producers would create invalid dissertation evidence.

## First Executed Plaintext Result Set

The first requested-baseline plaintext sweep executed was:

```text
config/sweeps/plaintext-requested/message_size_bytes.json
```

Result directory:

```text
results/plaintext-requested/plaintext-requested-message-size-bytes/
```

Run count:

```text
9 runs = 3 message sizes x 3 trials
```

Baseline settings for this result set:

```text
broker_count=3
replication_factor=3
min_insync_replicas=3
partition_count=6
target_messages_per_second=5000
batch_size=65536
acks=all
producer_count=1
compression_type=none
```

Grouped mean results:

| `message_size_bytes` | Throughput records/s | Throughput MB/s | Avg latency ms | Max latency ms |
|---:|---:|---:|---:|---:|
| 1024 | 4990.68 | 4.87 | 7.04 | 545.33 |
| 10240 | 4990.77 | 48.74 | 25.82 | 564.00 |
| 102400 | 1212.96 | 118.45 | 228.32 | 1325.67 |
