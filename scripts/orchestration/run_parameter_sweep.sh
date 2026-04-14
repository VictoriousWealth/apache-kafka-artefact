#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
SSH_OPTS=(-i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no -o ConnectTimeout=10)
REMOTE_RESULTS_DIR="${REMOTE_RESULTS_DIR:-/var/lib/kafka-client/results}"
LOCAL_RESULTS_DIR="${LOCAL_RESULTS_DIR:-results}"
SWEEP_FILE="${SWEEP_FILE:-config/sweeps/message_size_bytes.json}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_SLEEP_SECONDS="${RETRY_SLEEP_SECONDS:-5}"

if [[ -z "${SSH_KEY_PATH}" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

require_file "${INVENTORY_FILE}"
require_file "${SWEEP_FILE}"

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"

if [[ -z "${BENCHMARK_CLIENT_IP:-}" ]]; then
  echo "BENCHMARK_CLIENT_IP not found in inventory."
  exit 1
fi

BROKER_IPS=()
INDEX=1
while true; do
  VAR_NAME="BROKER_${INDEX}_IP"
  if [[ -z "${!VAR_NAME:-}" ]]; then
    break
  fi
  BROKER_IPS+=("${!VAR_NAME}")
  INDEX=$((INDEX + 1))
done

if [[ "${#BROKER_IPS[@]}" -eq 0 ]]; then
  echo "No broker IPs found in inventory."
  exit 1
fi

SWEEP_NAME="$(jq -r '.name' "${SWEEP_FILE}")"
BASELINE_NAME="$(jq -r '.baseline' "${SWEEP_FILE}")"
SWEEP_VARIABLE="$(jq -r '.variable' "${SWEEP_FILE}")"
TRIAL_COUNT="$(jq -r '.trials // 1' "${SWEEP_FILE}")"
BASELINE_FILE="config/baselines/${BASELINE_NAME}.json"

require_file "${BASELINE_FILE}"

BOOTSTRAP_SERVERS=""
for host in "${BROKER_IPS[@]}"; do
  if [[ -n "${BOOTSTRAP_SERVERS}" ]]; then
    BOOTSTRAP_SERVERS="${BOOTSTRAP_SERVERS},${host}:9092"
  else
    BOOTSTRAP_SERVERS="${host}:9092"
  fi
done

remote_ssh() {
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${BENCHMARK_CLIENT_IP}" "$@"
}

run_single_value() {
  local sweep_value="$1"
  local run_id="$2"
  local result_subdir="$3"
  local trial_index="$4"

  local config_json
  config_json="$(jq --arg variable "${SWEEP_VARIABLE}" --argjson value "$(jq -cn --arg raw "${sweep_value}" '$raw | fromjson? // $raw')" '.[$variable] = $value' "${BASELINE_FILE}")"

  local security_mode topic broker_count partition_count replication_factor message_size_bytes num_records target_messages_per_second producer_count consumer_count batch_size linger_ms acks
  security_mode="$(jq -r '.security_mode' <<< "${config_json}")"
  topic="$(jq -r '.topic' <<< "${config_json}")"
  broker_count="$(jq -r '.broker_count' <<< "${config_json}")"
  partition_count="$(jq -r '.partition_count' <<< "${config_json}")"
  replication_factor="$(jq -r '.replication_factor' <<< "${config_json}")"
  message_size_bytes="$(jq -r '.message_size_bytes' <<< "${config_json}")"
  num_records="$(jq -r '.num_records' <<< "${config_json}")"
  target_messages_per_second="$(jq -r '.target_messages_per_second' <<< "${config_json}")"
  producer_count="$(jq -r '.producer_count' <<< "${config_json}")"
  consumer_count="$(jq -r '.consumer_count' <<< "${config_json}")"
  batch_size="$(jq -r '.batch_size' <<< "${config_json}")"
  linger_ms="$(jq -r '.linger_ms' <<< "${config_json}")"
  acks="$(jq -r '.acks' <<< "${config_json}")"

  if [[ "${security_mode}" != "plaintext" ]]; then
    echo "Sweep value ${sweep_value} resolves to security_mode=${security_mode}, which is not yet implemented."
    exit 1
  fi

  mkdir -p "${LOCAL_RESULTS_DIR}/${result_subdir}"

  log "Running sweep ${SWEEP_NAME}: ${SWEEP_VARIABLE}=${sweep_value}"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh \
    "sudo BOOTSTRAP_SERVERS='${BOOTSTRAP_SERVERS}' TOPIC='${topic}' NUM_RECORDS='${num_records}' RECORD_SIZE='${message_size_bytes}' THROUGHPUT='${target_messages_per_second}' PARTITIONS='${partition_count}' REPLICATION_FACTOR='${replication_factor}' BROKER_COUNT='${broker_count}' BASELINE_NAME='${BASELINE_NAME}' SWEEP_NAME='${SWEEP_NAME}' SWEEP_VARIABLE='${SWEEP_VARIABLE}' SWEEP_VALUE='${sweep_value}' TRIAL_INDEX='${trial_index}' TRIAL_COUNT='${TRIAL_COUNT}' SECURITY_MODE='${security_mode}' PRODUCER_COUNT='${producer_count}' CONSUMER_COUNT='${consumer_count}' BATCH_SIZE='${batch_size}' LINGER_MS='${linger_ms}' ACKS='${acks}' RUN_ID='${run_id}' /usr/local/bin/run_plaintext_producer_perf.sh"

  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" scp "${SSH_OPTS[@]}" -r \
    "${SSH_USER}@${BENCHMARK_CLIENT_IP}:${REMOTE_RESULTS_DIR}/${run_id}" "${LOCAL_RESULTS_DIR}/${result_subdir}/"

  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" "${SCRIPT_DIR}/parse_producer_perf_results.sh" "${LOCAL_RESULTS_DIR}/${result_subdir}/${run_id}"
}

while IFS= read -r sweep_value; do
  safe_value="$(echo "${sweep_value}" | tr ' ' '_' | tr '/' '_' | tr ':' '_' | tr '"' '_' | tr ',' '_')"
  for ((trial_index = 1; trial_index <= TRIAL_COUNT; trial_index++)); do
    run_id="$(date -u +"%Y%m%dT%H%M%SZ")-${BASELINE_NAME}-${SWEEP_VARIABLE}-${safe_value}-trial${trial_index}"
    run_single_value "${sweep_value}" "${run_id}" "${SWEEP_NAME}" "${trial_index}"
  done
done < <(jq -cr '.values[]' "${SWEEP_FILE}")

"${SCRIPT_DIR}/aggregate_sweep_results.sh" "${LOCAL_RESULTS_DIR}/${SWEEP_NAME}"

log "Sweep ${SWEEP_NAME} completed."
