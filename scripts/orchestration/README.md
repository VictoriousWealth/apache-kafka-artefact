# Orchestration Scripts

These scripts connect Terraform provisioning and Kafka bootstrap into a simple remote deployment flow.

## Current Flow

1. `export_tf_outputs.sh`
   Save Terraform outputs to `.orchestration/terraform-output.json`

2. `build_inventory.sh`
   Convert Terraform outputs into an inventory of broker and client IPs

3. `build_cluster_metadata.sh`
   Derive the KRaft quorum voter string

4. `bootstrap_brokers.sh`
   Copy bootstrap assets to broker nodes, install Kafka, configure plaintext KRaft, and start Kafka

5. `prepare_benchmark_client.sh`
   Install baseline dependencies on the benchmark client node

6. `deploy_plaintext_cluster.sh`
   Run the full plaintext deployment flow with step checkpoints so interrupted runs can be resumed

7. `prepare_broker_count_phase.sh`
   Converge the AWS/Kafka environment to a clean 3-broker or 5-broker plaintext phase before running matching factorial rows

8. `run_parameter_sweep.sh`
   Execute a baseline-plus-sweep benchmark run set from the benchmark client and copy results back locally

9. `run_factorial_plan.sh`
   Execute a generated JSONL factorial plan with deterministic run IDs, checkpoint/resume support, broker-count filtering, failure logging, and optional dry-run/max-run controls

10. `parse_producer_perf_results.sh`
   Convert raw `producer-perf.log` output into a standard structured result schema

11. `aggregate_sweep_results.sh`
   Aggregate all per-run `result.json` files under a sweep into `summary.json` and `summary.csv`

12. `../analysis/export_sweep_artifacts.sh`
   Convert `summary.json` into dissertation-ready tables and SVG plots under an `export/` directory

## Broker-Count Phases

For dissertation correctness, `broker_count=3` and `broker_count=5` should be run as separate infrastructure phases.

Prepare a clean 3-broker phase:

```bash
TARGET_BROKER_COUNT=3 \
CONFIRM_DESTROY_EXTRA_BROKERS=true \
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
scripts/orchestration/prepare_broker_count_phase.sh
```

Prepare a clean 5-broker phase:

```bash
TARGET_BROKER_COUNT=5 \
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
scripts/orchestration/prepare_broker_count_phase.sh
```

The script updates `infrastructure/terraform/envs/dev/terraform.tfvars`, applies Terraform, rebuilds orchestration inventory, bootstraps Kafka with `RESET_KAFKA_STORAGE=true` by default, refreshes the benchmark client, and writes `.orchestration/broker-count-phase.env`.

Shrinking from 5 brokers to 3 brokers destroys the extra EC2 broker instances. The explicit `CONFIRM_DESTROY_EXTRA_BROKERS=true` flag is required for that transition.

## Factorial Execution

Generate the plaintext factorial plan:

```bash
scripts/orchestration/generate_factorial_plan.sh \
  config/factorials/plaintext-requested-full.json \
  .orchestration/plaintext-requested-full-plan.jsonl
```

Dry-run the first five rows for the active five-broker cluster:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
DRY_RUN=true \
BROKER_COUNT_FILTER=5 \
MAX_RUNS=5 \
AGGREGATE_RESULTS=false \
EXPORT_RESULTS=false \
scripts/orchestration/run_factorial_plan.sh
```

Run one real smoke row:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
BROKER_COUNT_FILTER=5 \
MAX_RUNS=1 \
AGGREGATE_RESULTS=false \
EXPORT_RESULTS=false \
LOCAL_RESULTS_DIR=results/factorial-smoke \
RESULT_SET_NAME=executor-smoke \
CHECKPOINT_FILE=.orchestration/executor-smoke.checkpoint \
scripts/orchestration/run_factorial_plan.sh
```

Run the five-broker portion of the plaintext plan:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
BROKER_COUNT_FILTER=5 \
LOCAL_RESULTS_DIR=results/factorial \
RESULT_SET_NAME=plaintext-requested-full-broker5 \
CHECKPOINT_FILE=.orchestration/plaintext-requested-full-broker5.checkpoint \
scripts/orchestration/run_factorial_plan.sh
```

The executor skips rows whose `broker_count` does not match the active cluster unless `ALLOW_CLUSTER_MISMATCH=true` is set. Do not use `ALLOW_CLUSTER_MISMATCH=true` for dissertation evidence unless the methodology explicitly defines what that means.

Factorial resumability files:

```text
.orchestration/<result-set>.checkpoint
results/factorial/<result-set>/started.jsonl
results/factorial/<result-set>/completed.jsonl
results/factorial/<result-set>/failures.jsonl
```

Resume behaviour:

- A run is considered complete if its run ID exists in the checkpoint file or if its local `result.json` exists.
- Remote result copying uses a temporary local directory first, so an interrupted `scp` does not create a false completed run.
- Existing incomplete local run directories are moved aside with a `.superseded-*` prefix when a run is copied again.
- Failed runs are recorded in `failures.jsonl` and the executor continues to the next planned row.
- Re-running the same command resumes the same result set.

Run the three-broker portion after preparing the 3-broker phase:

```bash
SSH_KEY_PATH=.orchestration/kafka-artefact-dev-key.pem \
BROKER_COUNT_FILTER=3 \
LOCAL_RESULTS_DIR=results/factorial \
RESULT_SET_NAME=plaintext-requested-full-broker3 \
CHECKPOINT_FILE=.orchestration/plaintext-requested-full-broker3.checkpoint \
scripts/orchestration/run_factorial_plan.sh
```

## Requirements

- `terraform`
- `jq`
- `ssh`
- `scp`
- access to the EC2 instances via an SSH key

## Notes

The current scripts assume:

- Terraform has already applied successfully
- all broker nodes are Ubuntu-based and reachable over SSH
- the SSH user is `ubuntu` unless overridden
- the first target is plaintext-only deployment

## Hardening Features

- retry handling for transient command failures
- atomic writes for generated local state files
- resumable checkpoints for the top-level plaintext deployment flow
- resumable checkpoints for factorial benchmark execution
- deterministic factorial run IDs so reruns do not create duplicate logical runs
- factorial failure logs under the result directory
- broker service health checks after startup
- Kafka API readiness checks after broker startup
