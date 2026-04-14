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
LOCAL_RESULTS_DIR="${LOCAL_RESULTS_DIR:-results/plaintext}"
SCENARIO_FILE="${SCENARIO_FILE:-config/scenarios/plaintext-low.json}"
TOPIC="${TOPIC:-benchmark-topic}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_SLEEP_SECONDS="${RETRY_SLEEP_SECONDS:-5}"

if [[ -z "${SSH_KEY_PATH}" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

require_file "${INVENTORY_FILE}"
require_file "${SCENARIO_FILE}"

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

SCENARIO_NAME="$(jq -r '.name' "${SCENARIO_FILE}")"
SECURITY_MODE="$(jq -r '.security_mode' "${SCENARIO_FILE}")"
WORKLOAD_NAME="$(jq -r '.workload' "${SCENARIO_FILE}")"
PARTITIONS="$(jq -r '.partition_count' "${SCENARIO_FILE}")"
REPLICATION_FACTOR="$(jq -r '.replication_factor' "${SCENARIO_FILE}")"
BROKER_COUNT="$(jq -r '.broker_count' "${SCENARIO_FILE}")"

if [[ "${SECURITY_MODE}" != "plaintext" ]]; then
  echo "Scenario ${SCENARIO_NAME} is not plaintext."
  exit 1
fi

WORKLOAD_FILE="config/workloads/${WORKLOAD_NAME}.json"
require_file "${WORKLOAD_FILE}"

NUM_RECORDS="$(jq -r '.num_records' "${WORKLOAD_FILE}")"
RECORD_SIZE="$(jq -r '.message_size_bytes' "${WORKLOAD_FILE}")"
THROUGHPUT="$(jq -r '.target_messages_per_second' "${WORKLOAD_FILE}")"
PRODUCER_COUNT="$(jq -r '.producer_count' "${WORKLOAD_FILE}")"
CONSUMER_COUNT="$(jq -r '.consumer_count' "${WORKLOAD_FILE}")"
BATCH_SIZE="$(jq -r '.batch_size' "${WORKLOAD_FILE}")"
LINGER_MS="$(jq -r '.linger_ms' "${WORKLOAD_FILE}")"
ACKS="$(jq -r '.acks' "${WORKLOAD_FILE}")"
RUN_ID="${RUN_ID:-$(date -u +"%Y%m%dT%H%M%SZ")-${SCENARIO_NAME}}"

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

mkdir -p "${LOCAL_RESULTS_DIR}"

log "Running plaintext producer baseline from ${BENCHMARK_CLIENT_IP}"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh \
  "sudo BOOTSTRAP_SERVERS='${BOOTSTRAP_SERVERS}' TOPIC='${TOPIC}' NUM_RECORDS='${NUM_RECORDS}' RECORD_SIZE='${RECORD_SIZE}' THROUGHPUT='${THROUGHPUT}' PARTITIONS='${PARTITIONS}' REPLICATION_FACTOR='${REPLICATION_FACTOR}' BROKER_COUNT='${BROKER_COUNT}' SCENARIO_NAME='${SCENARIO_NAME}' WORKLOAD_NAME='${WORKLOAD_NAME}' SECURITY_MODE='${SECURITY_MODE}' PRODUCER_COUNT='${PRODUCER_COUNT}' CONSUMER_COUNT='${CONSUMER_COUNT}' BATCH_SIZE='${BATCH_SIZE}' LINGER_MS='${LINGER_MS}' ACKS='${ACKS}' RUN_ID='${RUN_ID}' /usr/local/bin/run_plaintext_producer_perf.sh"

run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" scp "${SSH_OPTS[@]}" -r \
  "${SSH_USER}@${BENCHMARK_CLIENT_IP}:${REMOTE_RESULTS_DIR}/${RUN_ID}" "${LOCAL_RESULTS_DIR}/"

run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" "${SCRIPT_DIR}/parse_producer_perf_results.sh" "${LOCAL_RESULTS_DIR}/${RUN_ID}"

log "Plaintext producer baseline results copied to ${LOCAL_RESULTS_DIR}/${RUN_ID}"
