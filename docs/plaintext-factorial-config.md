# Plaintext Factorial Configuration

## Purpose

This document records the proposed plaintext-only experiment matrix before extending the same configuration space to TLS and mTLS. The aim is to preserve the full set of values under consideration while making the run count and Kafka validity constraints explicit.

This is not yet the default executable sweep. The current runner supports one-factor-at-a-time sweeps. Running this matrix requires either a factorial executor or a generated set of single-run configurations.

## Security Mode

The first execution phase is plaintext only:

```text
security_mode = plaintext
```

TLS and mTLS should reuse the same matrix only after the plaintext execution path is stable.

## Requested Parameter Values

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

## Recommended Plaintext Start

Use the requested matrix as the full design space, but start with a staged plaintext execution:

1. Run a smoke set with the baseline workload across the four valid deployment/durability combinations.
2. Run one-factor-at-a-time plaintext sweeps against the stable baseline.
3. Use the strongest plaintext effects to choose a smaller security-comparison matrix for TLS and mTLS.

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

Recommended first plaintext sweeps:

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

This produces usable plaintext evidence quickly while keeping the full factorial design documented for later selective expansion.

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
