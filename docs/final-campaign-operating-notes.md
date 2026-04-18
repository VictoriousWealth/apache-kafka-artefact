# Final Campaign Operating Notes

## Purpose

This document records how to run the final security-overhead campaign safely and reproducibly. It is operational guidance for executing the dissertation experiment without mixing incompatible result sets, accidentally running the wrong Kafka security mode, or creating unnecessary AWS cost.

The final campaign config is:

```text
config/factorials/security-overhead-final.json
```

The generated plan is:

```text
.orchestration/security-overhead-final-plan.jsonl
```

Generate or refresh it with:

```bash
scripts/orchestration/generate_factorial_plan.sh \
  config/factorials/security-overhead-final.json \
  .orchestration/security-overhead-final-plan.jsonl
```

## Campaign Size

Total planned rows:

```text
5,184
```

Breakdown by security mode:

| Security mode | Runs |
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

The campaign should not be started as one unattended 5,184-run command. Use resumable phase batches.

## Phase Model

Each phase is defined by:

```text
security_mode + broker_count
```

Valid final phases:

| Phase | Security mode | Broker count | Runs |
|---|---|---:|---:|
| 1 | `mtls` | 5 | 1,296 |
| 2 | `tls` | 5 | 1,296 |
| 3 | `plaintext` | 5 | 1,296 |
| 4 | `mtls` | 3 | 432 |
| 5 | `tls` | 3 | 432 |
| 6 | `plaintext` | 3 | 432 |

The recommended order starts with `mtls` broker-5 because the live cluster is currently in mTLS mode. Do not shrink to 3 brokers until the broker-5 phases that you intend to keep are complete.

## Current State

Current in-progress final result set:

```text
results/factorial-final/security-overhead-final-mtls-broker5/
```

Current checkpoint:

```text
.orchestration/security-overhead-final-mtls-broker5.checkpoint
```

At the time this note was added, the mTLS broker-5 phase had started and the executor had validated the enriched metric pipeline.

## Mode Deployment Rule

The active Kafka deployment mode must match the rows being executed.

| Rows being run | Required cluster deployment |
|---|---|
| `SECURITY_MODE_FILTER=plaintext` | Plaintext Kafka listener on `9092`. |
| `SECURITY_MODE_FILTER=tls` | TLS Kafka listener on `9094`. |
| `SECURITY_MODE_FILTER=mtls` | mTLS Kafka listener on `9094` with client certificates. |

Do not run plaintext rows against a TLS or mTLS cluster. Do not run TLS/mTLS rows against a plaintext cluster.

Deployment commands:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
scripts/orchestration/deploy_plaintext_cluster.sh
```

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
scripts/orchestration/deploy_tls_cluster.sh
```

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
scripts/orchestration/deploy_mtls_cluster.sh
```

## Broker-Count Rule

The active broker count must match `BROKER_COUNT_FILTER`.

Do not run `broker_count=3` rows on a five-broker cluster and label them as three-broker results.

Prepare five brokers:

```bash
TARGET_BROKER_COUNT=5 \
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
scripts/orchestration/prepare_broker_count_phase.sh
```

Prepare three brokers:

```bash
TARGET_BROKER_COUNT=3 \
CONFIRM_DESTROY_EXTRA_BROKERS=true \
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
scripts/orchestration/prepare_broker_count_phase.sh
```

Shrinking from five to three brokers destroys the extra broker EC2 instances. Only do this after collecting the five-broker evidence you intend to keep.

## Batch Size Guidance

Use bounded batches:

| Batch size | Use case |
|---|---|
| `MAX_RUNS=1` | Live validation after code changes. |
| `MAX_RUNS=25` | Conservative batch while checking stability. |
| `MAX_RUNS=50` | Normal safe batch. |
| `MAX_RUNS=100` | Larger batch once a phase has shown stable execution. |

Avoid starting a full 1,296-run phase until runtime, cost, and failure behaviour are understood.

Example mTLS broker-5 batch:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
FACTORIAL_PLAN_FILE=.orchestration/security-overhead-final-plan.jsonl \
SECURITY_MODE_FILTER=mtls \
BROKER_COUNT_FILTER=5 \
MAX_RUNS=50 \
LOCAL_RESULTS_DIR=results/factorial-final \
RESULT_SET_NAME=security-overhead-final-mtls-broker5 \
CHECKPOINT_FILE=.orchestration/security-overhead-final-mtls-broker5.checkpoint \
AGGREGATE_RESULTS=true \
EXPORT_RESULTS=false \
scripts/orchestration/run_factorial_plan.sh
```

The same command pattern applies to `plaintext` and `tls`; change `SECURITY_MODE_FILTER`, `RESULT_SET_NAME`, and `CHECKPOINT_FILE`.

## Canonical Result Paths

Use these canonical paths for final producer campaign results:

```text
results/factorial-final/security-overhead-final-plaintext-broker5/
results/factorial-final/security-overhead-final-tls-broker5/
results/factorial-final/security-overhead-final-mtls-broker5/
results/factorial-final/security-overhead-final-plaintext-broker3/
results/factorial-final/security-overhead-final-tls-broker3/
results/factorial-final/security-overhead-final-mtls-broker3/
```

Use matching checkpoint paths:

```text
.orchestration/security-overhead-final-plaintext-broker5.checkpoint
.orchestration/security-overhead-final-tls-broker5.checkpoint
.orchestration/security-overhead-final-mtls-broker5.checkpoint
.orchestration/security-overhead-final-plaintext-broker3.checkpoint
.orchestration/security-overhead-final-tls-broker3.checkpoint
.orchestration/security-overhead-final-mtls-broker3.checkpoint
```

## Progress Checks

Check phase progress with:

```bash
wc -l results/factorial-final/<result-set>/completed.jsonl
wc -l results/factorial-final/<result-set>/started.jsonl
test -f results/factorial-final/<result-set>/failures.jsonl && \
  wc -l results/factorial-final/<result-set>/failures.jsonl
```

Check summary counters with:

```bash
jq '{run_count, started_count, completed_count, failure_count}' \
  results/factorial-final/<result-set>/summary.json
```

Expected healthy state:

```text
run_count == completed_count
failure_count == 0
telemetry_host_count == active broker count + 1
```

For five-broker phases, `telemetry_host_count` should normally be `6`. For three-broker phases, it should normally be `4`.

## What Not To Mix

Do not mix these into final security-overhead comparisons:

| Result set | Reason |
|---|---|
| `results/factorial/plaintext-requested-full-broker5/` | Older plaintext validation set without host telemetry. |
| `results/plaintext-full/` | Interrupted early run. |
| `results/plaintext-full-fixed/` | Valid one-factor sweep, but not part of the final matched factorial campaign. |
| smoke-only result sets | Useful for validation, but insufficient for final campaign conclusions. |

Final security-overhead comparisons should use matched rows from the canonical `results/factorial-final/` paths.

Historical result sets can still be cited as engineering validation evidence, for example to explain how the pipeline was hardened after interruption or how concurrent producer support was validated. They should be labelled as historical validation, not final evaluation data.

## Comparison Exports

After matched plaintext, TLS, and mTLS summaries exist for a broker-count phase, export comparisons with the final-phase wrapper.

For broker-5:

```bash
scripts/analysis/export_final_phase_comparison.sh --broker-count 5
```

For broker-3:

```bash
scripts/analysis/export_final_phase_comparison.sh --broker-count 3
```

The wrapper expects the canonical result paths documented above and writes to:

```text
results/factorial-final/security-overhead-final-broker5-comparison/
results/factorial-final/security-overhead-final-broker3-comparison/
```

Equivalent manual broker-5 command:

```bash
scripts/analysis/export_security_comparison.sh \
  results/factorial-final/security-overhead-final-broker5-comparison \
  results/factorial-final/security-overhead-final-plaintext-broker5/summary.csv \
  results/factorial-final/security-overhead-final-tls-broker5/summary.csv \
  results/factorial-final/security-overhead-final-mtls-broker5/summary.csv
```

Equivalent manual broker-3 command:

```bash
scripts/analysis/export_security_comparison.sh \
  results/factorial-final/security-overhead-final-broker3-comparison \
  results/factorial-final/security-overhead-final-plaintext-broker3/summary.csv \
  results/factorial-final/security-overhead-final-tls-broker3/summary.csv \
  results/factorial-final/security-overhead-final-mtls-broker3/summary.csv
```

The comparison exporter joins by workload/deployment fields, not by `run_id`.

## AWS Cost And Runtime Control

AWS resources continue to cost money while running.

Destroy the environment only when you no longer need live brokers:

```bash
terraform -chdir=infrastructure/terraform/envs/dev destroy
```

Do not destroy the environment while a phase is running or before copying and aggregating all required result files.

## Pre-Run Checklist

Before each batch:

- Confirm the active Kafka security mode matches `SECURITY_MODE_FILTER`.
- Confirm the active broker count matches `BROKER_COUNT_FILTER`.
- Confirm benchmark client scripts are installed.
- Confirm `FACTORIAL_PLAN_FILE` exists and has `5,184` lines.
- Confirm `RESULT_SET_NAME` and `CHECKPOINT_FILE` match the phase.
- Use a bounded `MAX_RUNS` value.
- Make sure no other benchmark run is already active.

## Post-Run Checklist

After each batch:

- Confirm the command exited with code `0`.
- Check `completed.jsonl`, `started.jsonl`, and `failures.jsonl`.
- Check `summary.json` counters.
- Confirm new rows have telemetry fields populated.
- Keep the AWS cost note in mind before taking a break.
