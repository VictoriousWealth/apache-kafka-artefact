#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
METADATA_FILE="${METADATA_FILE:-${OUTPUT_DIR}/cluster.env}"
FACTORIAL_PLAN_FILE="${FACTORIAL_PLAN_FILE:-${OUTPUT_DIR}/plaintext-requested-full-plan.jsonl}"
SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
REMOTE_RESULTS_DIR="${REMOTE_RESULTS_DIR:-/var/lib/kafka-client/results}"
LOCAL_RESULTS_DIR="${LOCAL_RESULTS_DIR:-results/factorial}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_SLEEP_SECONDS="${RETRY_SLEEP_SECONDS:-5}"
MAX_RUNS="${MAX_RUNS:-0}"
DRY_RUN="${DRY_RUN:-false}"
ALLOW_CLUSTER_MISMATCH="${ALLOW_CLUSTER_MISMATCH:-false}"
BROKER_COUNT_FILTER="${BROKER_COUNT_FILTER:-}"
SECURITY_MODE_FILTER="${SECURITY_MODE_FILTER:-}"
EXPORT_RESULTS="${EXPORT_RESULTS:-true}"
AGGREGATE_RESULTS="${AGGREGATE_RESULTS:-true}"

if [[ -z "${SSH_KEY_PATH}" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

require_file "${INVENTORY_FILE}"
require_file "${METADATA_FILE}"
require_file "${FACTORIAL_PLAN_FILE}"

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"
# shellcheck disable=SC1090
source "${METADATA_FILE}"

if [[ -z "${BENCHMARK_CLIENT_IP:-}" ]]; then
  echo "BENCHMARK_CLIENT_IP not found in inventory."
  exit 1
fi

if [[ -z "${BOOTSTRAP_SERVERS:-}" ]]; then
  echo "BOOTSTRAP_SERVERS not found in cluster metadata."
  exit 1
fi

if ! jq -e . "${FACTORIAL_PLAN_FILE}" >/dev/null 2>&1; then
  # jsonl is expected, so validate line-by-line instead.
  while IFS= read -r plan_line; do
    [[ -z "${plan_line}" ]] && continue
    jq -e . >/dev/null <<< "${plan_line}"
  done < "${FACTORIAL_PLAN_FILE}"
fi

SSH_OPTS=(-i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no -o ConnectTimeout=10)
PLAN_RUN_COUNT="$(grep -cve '^[[:space:]]*$' "${FACTORIAL_PLAN_FILE}")"
FACTORIAL_NAME="$(jq -r '.factorial_name' < <(grep -m1 -ve '^[[:space:]]*$' "${FACTORIAL_PLAN_FILE}"))"
RESULT_SET_NAME="${RESULT_SET_NAME:-${FACTORIAL_NAME}}"
RESULT_DIR="${LOCAL_RESULTS_DIR}/${RESULT_SET_NAME}"
CHECKPOINT_FILE="${CHECKPOINT_FILE:-${OUTPUT_DIR}/${RESULT_SET_NAME}.checkpoint}"
FAILED_FILE="${FAILED_FILE:-${RESULT_DIR}/failures.jsonl}"
STARTED_FILE="${STARTED_FILE:-${RESULT_DIR}/started.jsonl}"
COMPLETED_FILE="${COMPLETED_FILE:-${RESULT_DIR}/completed.jsonl}"

mkdir -p "${RESULT_DIR}"

remote_ssh() {
  ssh -n "${SSH_OPTS[@]}" "${SSH_USER}@${BENCHMARK_CLIENT_IP}" "$@"
}

append_jsonl_atomic() {
  local target_file="$1"
  local json_line="$2"
  local temp_file

  mkdir -p "$(dirname "${target_file}")"
  temp_file="$(mktemp "$(dirname "${target_file}")/$(basename "${target_file}").XXXXXX")"
  if [[ -f "${target_file}" ]]; then
    cat "${target_file}" > "${temp_file}"
  fi
  printf '%s\n' "${json_line}" >> "${temp_file}"
  mv "${temp_file}" "${target_file}"
}

write_started() {
  local run_id="$1"
  local factorial_name="$2"
  local broker_count="$3"
  local replication_factor="$4"
  local min_insync_replicas="$5"
  local trial_index="$6"

  append_jsonl_atomic "${STARTED_FILE}" "$(
    jq -cn \
      --arg run_id "${run_id}" \
      --arg factorial_name "${factorial_name}" \
      --argjson broker_count "${broker_count}" \
      --argjson replication_factor "${replication_factor}" \
      --argjson min_insync_replicas "${min_insync_replicas}" \
      --argjson trial_index "${trial_index}" \
      --arg started_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '{
        run_id: $run_id,
        factorial_name: $factorial_name,
        broker_count: $broker_count,
        replication_factor: $replication_factor,
        min_insync_replicas: $min_insync_replicas,
        trial_index: $trial_index,
        started_at: $started_at
      }'
  )"
}

write_completed() {
  local run_id="$1"
  local result_json="$2"

  append_jsonl_atomic "${COMPLETED_FILE}" "$(
    jq -cn \
      --arg run_id "${run_id}" \
      --arg result_json "${result_json}" \
      --arg completed_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '{
        run_id: $run_id,
        result_json: $result_json,
        completed_at: $completed_at
      }'
  )"
}

copy_result_back() {
  local run_id="$1"
  local temp_parent
  local temp_result_dir

  temp_parent="$(mktemp -d "${RESULT_DIR}/.copy-${run_id}.XXXXXX")"
  scp "${SSH_OPTS[@]}" -r \
    "${SSH_USER}@${BENCHMARK_CLIENT_IP}:${REMOTE_RESULTS_DIR}/${run_id}" "${temp_parent}/"

  temp_result_dir="${temp_parent}/${run_id}"
  if [[ ! -d "${temp_result_dir}" ]]; then
    echo "Copied result directory not found at ${temp_result_dir}"
    return 1
  fi

  if [[ -e "${RESULT_DIR}/${run_id}" ]]; then
    mv "${RESULT_DIR}/${run_id}" "${RESULT_DIR}/.superseded-${run_id}-$(date -u +"%Y%m%dT%H%M%SZ")"
  fi
  mv "${temp_result_dir}" "${RESULT_DIR}/${run_id}"
  rmdir "${temp_parent}"
}

plan_rows() {
  jq -r '
    def safe: tostring | gsub("[ /:,\\\"]"; "_");
    . as $row |
    (
      $row.run_id //
      "\($row.factorial_name)-b\($row.broker_count)-rf\($row.replication_factor)-isr\($row.min_insync_replicas)-msg\($row.message_size_bytes)-tps\($row.target_messages_per_second)-batch\($row.batch_size)-acks\($row.acks | safe)-prod\($row.producer_count)-comp\($row.compression_type | safe)-trial\($row.trial_index)"
    ) as $run_id |
    [
      $run_id,
      $row.factorial_name,
      $row.security_mode,
      $row.topic,
      $row.broker_count,
      $row.partition_count,
      $row.replication_factor,
      $row.min_insync_replicas,
      $row.message_size_bytes,
      $row.num_records,
      $row.target_messages_per_second,
      $row.producer_count,
      $row.consumer_count,
      $row.batch_size,
      $row.linger_ms,
      $row.acks,
      $row.compression_type,
      $row.trial_index,
      $row.trial_count
    ] | @tsv
  ' "${FACTORIAL_PLAN_FILE}"
}

write_failure() {
  local run_id="$1"
  local reason="$2"
  local factorial_name="$3"
  local security_mode="$4"
  local broker_count="$5"
  local replication_factor="$6"
  local min_insync_replicas="$7"
  local message_size_bytes="$8"
  local target_messages_per_second="$9"
  shift 9
  local batch_size="$1"
  local acks="$2"
  local producer_count="$3"
  local compression_type="$4"
  local trial_index="$5"

  append_jsonl_atomic "${FAILED_FILE}" "$(
    jq -cn \
    --arg run_id "${run_id}" \
    --arg reason "${reason}" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg factorial_name "${factorial_name}" \
    --arg security_mode "${security_mode}" \
    --argjson broker_count "${broker_count}" \
    --argjson replication_factor "${replication_factor}" \
    --argjson min_insync_replicas "${min_insync_replicas}" \
    --argjson message_size_bytes "${message_size_bytes}" \
    --argjson target_messages_per_second "${target_messages_per_second}" \
    --argjson batch_size "${batch_size}" \
    --arg acks "${acks}" \
    --argjson producer_count "${producer_count}" \
    --arg compression_type "${compression_type}" \
    --argjson trial_index "${trial_index}" \
    '{
      run_id: $run_id,
      factorial_name: $factorial_name,
      security_mode: $security_mode,
      broker_count: $broker_count,
      replication_factor: $replication_factor,
      min_insync_replicas: $min_insync_replicas,
      message_size_bytes: $message_size_bytes,
      target_messages_per_second: $target_messages_per_second,
      batch_size: $batch_size,
      acks: $acks,
      producer_count: $producer_count,
      compression_type: $compression_type,
      trial_index: $trial_index,
      failure_reason: $reason,
      failed_at: $timestamp
    }'
  )"
}

run_single_config() {
  local run_id="$1"
  local factorial_name="$2"
  local security_mode="$3"
  local topic="$4"
  local broker_count="$5"
  local partition_count="$6"
  local replication_factor="$7"
  local min_insync_replicas="$8"
  local message_size_bytes="$9"
  shift 9
  local num_records="$1"
  local target_messages_per_second="$2"
  local producer_count="$3"
  local consumer_count="$4"
  local batch_size="$5"
  local linger_ms="$6"
  local acks="$7"
  local compression_type="$8"
  local trial_index="$9"
  shift 9
  local trial_count="$1"

  if [[ "${security_mode}" != "plaintext" ]]; then
    echo "Only plaintext factorial execution is implemented. Found security_mode=${security_mode}."
    return 1
  fi

  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh \
    "sudo BOOTSTRAP_SERVERS='${BOOTSTRAP_SERVERS}' TOPIC='${topic}' NUM_RECORDS='${num_records}' RECORD_SIZE='${message_size_bytes}' THROUGHPUT='${target_messages_per_second}' PARTITIONS='${partition_count}' REPLICATION_FACTOR='${replication_factor}' MIN_INSYNC_REPLICAS='${min_insync_replicas}' BROKER_COUNT='${broker_count}' BASELINE_NAME='${factorial_name}' SWEEP_NAME='${factorial_name}' SWEEP_VARIABLE='factorial_config' SWEEP_VALUE='${run_id}' TRIAL_INDEX='${trial_index}' TRIAL_COUNT='${trial_count}' SECURITY_MODE='${security_mode}' PRODUCER_COUNT='${producer_count}' CONSUMER_COUNT='${consumer_count}' BATCH_SIZE='${batch_size}' LINGER_MS='${linger_ms}' ACKS='${acks}' COMPRESSION_TYPE='${compression_type}' RUN_ID='${run_id}' /usr/local/bin/run_plaintext_producer_perf.sh"

  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" copy_result_back "${run_id}"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" "${SCRIPT_DIR}/parse_producer_perf_results.sh" "${RESULT_DIR}/${run_id}"
}

on_interrupt() {
  log "Factorial execution interrupted. Re-run the same command to resume from ${CHECKPOINT_FILE}."
  exit 130
}

trap on_interrupt INT TERM

log "Starting factorial plan ${FACTORIAL_PLAN_FILE}"
log "Plan rows: ${PLAN_RUN_COUNT}; result directory: ${RESULT_DIR}"
if [[ -n "${BROKER_COUNT_FILTER}" ]]; then
  log "Applying broker_count filter: ${BROKER_COUNT_FILTER}"
fi
if [[ -n "${SECURITY_MODE_FILTER}" ]]; then
  log "Applying security_mode filter: ${SECURITY_MODE_FILTER}"
fi
if [[ "${DRY_RUN}" == "true" ]]; then
  log "Dry-run mode enabled; no remote benchmarks will be executed."
fi

processed_count=0
executed_count=0
skipped_count=0
failed_count=0

while IFS=$'\t' read -r run_id factorial_name security_mode topic row_broker_count partition_count replication_factor min_insync_replicas message_size_bytes num_records target_messages_per_second producer_count consumer_count batch_size linger_ms acks compression_type trial_index trial_count; do
  processed_count=$((processed_count + 1))

  if [[ -n "${BROKER_COUNT_FILTER}" && "${row_broker_count}" != "${BROKER_COUNT_FILTER}" ]]; then
    skipped_count=$((skipped_count + 1))
    continue
  fi

  if [[ -n "${SECURITY_MODE_FILTER}" && "${security_mode}" != "${SECURITY_MODE_FILTER}" ]]; then
    skipped_count=$((skipped_count + 1))
    continue
  fi

  if [[ "${ALLOW_CLUSTER_MISMATCH}" != "true" && "${row_broker_count}" != "${BROKER_COUNT}" ]]; then
    log "Skipping ${run_id}: plan broker_count=${row_broker_count}, active cluster BROKER_COUNT=${BROKER_COUNT}"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  if checkpoint_done "${CHECKPOINT_FILE}" "${run_id}" || [[ -f "${RESULT_DIR}/${run_id}/result.json" ]]; then
    log "Skipping completed run ${run_id}"
    mark_checkpoint "${CHECKPOINT_FILE}" "${run_id}"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  if [[ "${MAX_RUNS}" != "0" && "${executed_count}" -ge "${MAX_RUNS}" ]]; then
    log "Reached MAX_RUNS=${MAX_RUNS}; stopping."
    break
  fi

  log "Executing ${run_id}"
  if [[ "${DRY_RUN}" == "true" ]]; then
    log "Dry run would execute ${run_id}"
    executed_count=$((executed_count + 1))
    continue
  fi

  write_started "${run_id}" "${factorial_name}" "${row_broker_count}" "${replication_factor}" "${min_insync_replicas}" "${trial_index}"
  if run_single_config "${run_id}" "${factorial_name}" "${security_mode}" "${topic}" "${row_broker_count}" "${partition_count}" "${replication_factor}" "${min_insync_replicas}" "${message_size_bytes}" "${num_records}" "${target_messages_per_second}" "${producer_count}" "${consumer_count}" "${batch_size}" "${linger_ms}" "${acks}" "${compression_type}" "${trial_index}" "${trial_count}"; then
    mark_checkpoint "${CHECKPOINT_FILE}" "${run_id}"
    write_completed "${run_id}" "${RESULT_DIR}/${run_id}/result.json"
    executed_count=$((executed_count + 1))
  else
    write_failure "${run_id}" "benchmark execution failed" "${factorial_name}" "${security_mode}" "${row_broker_count}" "${replication_factor}" "${min_insync_replicas}" "${message_size_bytes}" "${target_messages_per_second}" "${batch_size}" "${acks}" "${producer_count}" "${compression_type}" "${trial_index}"
    failed_count=$((failed_count + 1))
    log "Run failed: ${run_id}; recorded in ${FAILED_FILE}"
  fi
done < <(plan_rows)

log "Factorial execution complete: processed=${processed_count}, executed=${executed_count}, skipped=${skipped_count}, failed=${failed_count}"

if [[ "${DRY_RUN}" != "true" && "${AGGREGATE_RESULTS}" == "true" ]]; then
  "${SCRIPT_DIR}/aggregate_sweep_results.sh" "${RESULT_DIR}"
fi

if [[ "${DRY_RUN}" != "true" && "${EXPORT_RESULTS}" == "true" && -f "${RESULT_DIR}/summary.json" ]]; then
  "${SCRIPT_DIR}/../analysis/export_sweep_artifacts.sh" "${RESULT_DIR}/summary.json"
fi
