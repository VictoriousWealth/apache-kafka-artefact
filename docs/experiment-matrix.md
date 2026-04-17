# Experiment Matrix

## Purpose

This document records the current experiment matrix for the dissertation artefact. The final campaign is a reduced security-overhead factorial design intended to remain broad enough to cover different Kafka operating conditions while avoiding the earlier 11,664-run explosion.

## Final Campaign Config

Machine-readable config:

```text
config/factorials/security-overhead-final.json
```

Generated plan:

```text
.orchestration/security-overhead-final-plan.jsonl
```

Generate or refresh the plan with:

```bash
scripts/orchestration/generate_factorial_plan.sh \
  config/factorials/security-overhead-final.json \
  .orchestration/security-overhead-final-plan.jsonl
```

Expected output:

```text
5184 planned runs
```

## Final Parameter Values

| Parameter | Values | Count |
|---|---|---:|
| `security_mode` | `plaintext`, `tls`, `mtls` | 3 |
| valid `broker_count` / `replication_factor` / `min_insync_replicas` combinations | see validity table below | 4 |
| `message_size_bytes` | `1024`, `10240`, `102400` | 3 |
| `target_messages_per_second` | `1000`, `10000` | 2 |
| `batch_size` | `16384`, `131072` | 2 |
| `acks` | `1`, `all` | 2 |
| `producer_count` | `1`, `6`, `12` | 3 |
| `compression_type` | `none`, `lz4` | 2 |
| `trials` | `1`, `2`, `3` | 3 |

The final matrix intentionally excludes:

```text
target_messages_per_second = 5000
batch_size = 65536
```

Those middle values were removed to keep the campaign tractable while preserving low/high contrasts for throughput target and producer batch size.

## Kafka Validity Rules

Required constraints:

```text
replication_factor <= broker_count
min_insync_replicas <= replication_factor
```

Valid deployment/durability combinations:

| `broker_count` | `replication_factor` | `min_insync_replicas` |
|---:|---:|---:|
| 3 | 3 | 3 |
| 5 | 3 | 3 |
| 5 | 5 | 3 |
| 5 | 5 | 4 |

Invalid combinations removed from the generated plan:

```text
broker_count=3, replication_factor=5
replication_factor=3, min_insync_replicas=4
```

## Run Count

Per security mode:

```text
4 x 3 x 2 x 2 x 2 x 3 x 2 x 3 = 1728 runs
```

Across all security modes:

```text
1728 x 3 = 5184 runs
```

Breakdown by security mode:

| `security_mode` | Runs |
|---|---:|
| `plaintext` | 1,728 |
| `tls` | 1,728 |
| `mtls` | 1,728 |
| **Total** | **5,184** |

Breakdown by broker-count phase:

| Broker phase | Runs per security mode | Runs across all modes |
|---|---:|---:|
| 3 brokers | 432 | 1,296 |
| 5 brokers | 1,296 | 3,888 |
| **Total** | **1,728** | **5,184** |

## Execution Phases

Broker count must reflect the real active cluster. Do not run `broker_count=3` rows on a five-broker cluster and label them as three-broker results.

Recommended phase structure:

| Phase | `security_mode` | `broker_count` | Runs |
|---|---|---:|---:|
| 1 | `plaintext` | 5 | 1,296 |
| 2 | `tls` | 5 | 1,296 |
| 3 | `mtls` | 5 | 1,296 |
| 4 | `plaintext` | 3 | 432 |
| 5 | `tls` | 3 | 432 |
| 6 | `mtls` | 3 | 432 |

The current executor can generate all rows, but only plaintext execution is implemented. TLS and mTLS rows must not be run until the corresponding deployment and client paths exist.

Example plaintext five-broker command:

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

## Relationship To Earlier Plans

The earlier requested plaintext-only design is documented in:

```text
docs/plaintext-factorial-config.md
config/factorials/plaintext-requested-full.json
```

That earlier matrix used:

```text
target_messages_per_second = 1000, 5000, 10000
batch_size = 16384, 65536, 131072
```

It produced:

```text
3888 plaintext runs
11664 runs if repeated across plaintext, TLS, and mTLS
```

The reduced final campaign supersedes that plan for final dissertation evidence.

## Reporting Guidance

The dissertation should report:

- completion and failure counts per phase
- matched plaintext/TLS/mTLS throughput overhead
- matched plaintext/TLS/mTLS latency overhead
- host telemetry, especially CPU, once implemented
- critical discussion of which parameters amplify or reduce security overhead

