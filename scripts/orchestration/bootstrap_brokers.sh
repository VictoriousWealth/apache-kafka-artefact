#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
METADATA_FILE="${METADATA_FILE:-${OUTPUT_DIR}/cluster.env}"
SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
REMOTE_DIR="${REMOTE_DIR:-/tmp/kafka-bootstrap}"
SSH_OPTS=()
TEMP_CLUSTER_ID=""
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_SLEEP_SECONDS="${RETRY_SLEEP_SECONDS:-5}"

cleanup() {
  if [[ -n "${TEMP_CLUSTER_ID}" && -f "${TEMP_CLUSTER_ID}" ]]; then
    rm -f "${TEMP_CLUSTER_ID}"
  fi
}

on_interrupt() {
  echo "Bootstrap interrupted. Re-running the script is safe."
  exit 130
}

trap cleanup EXIT
trap on_interrupt INT TERM

if [[ -z "${SSH_KEY_PATH}" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

SSH_OPTS=(-i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no -o ConnectTimeout=10)

require_file "${INVENTORY_FILE}"
require_file "${METADATA_FILE}"

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"
# shellcheck disable=SC1090
source "${METADATA_FILE}"

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

remote_ssh() {
  local host="$1"
  shift
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${host}" "$@"
}

remote_scp_to() {
  local host="$1"
  shift
  scp "${SSH_OPTS[@]}" "$@" "${SSH_USER}@${host}:${REMOTE_DIR}/"
}

wait_for_kafka_service() {
  local host="$1"
  local attempt=1
  while (( attempt <= MAX_RETRIES )); do
    if remote_ssh "${host}" "sudo systemctl is-active --quiet kafka"; then
      return 0
    fi
    sleep "${RETRY_SLEEP_SECONDS}"
    attempt=$((attempt + 1))
  done
  return 1
}

wait_for_kafka_api() {
  local host="$1"
  local attempt=1
  local remote_cmd="sudo /opt/kafka_2.13-3.8.0/bin/kafka-broker-api-versions.sh --bootstrap-server ${host}:9092 >/dev/null 2>&1"
  while (( attempt <= MAX_RETRIES )); do
    if remote_ssh "${host}" "${remote_cmd}"; then
      return 0
    fi
    sleep "${RETRY_SLEEP_SECONDS}"
    attempt=$((attempt + 1))
  done
  return 1
}

for i in "${!BROKER_IPS[@]}"; do
  HOST="${BROKER_IPS[$i]}"

  log "Preparing broker host ${HOST}"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "mkdir -p ${REMOTE_DIR}"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_scp_to "${HOST}" \
    deploy/kafka/bootstrap/install_kafka.sh \
    deploy/kafka/bootstrap/generate_cluster_id.sh \
    deploy/kafka/bootstrap/configure_kafka_plaintext.sh \
    deploy/kafka/bootstrap/create_systemd_service.sh \
    deploy/kafka/config/server.properties.plaintext.template

  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo bash ${REMOTE_DIR}/install_kafka.sh"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo install -m 0644 -o kafka -g kafka ${REMOTE_DIR}/server.properties.plaintext.template /etc/kafka/server.properties.template"
done

FIRST_BROKER="${BROKER_IPS[0]}"
TEMP_CLUSTER_ID="$(mktemp "${OUTPUT_DIR}/cluster.id.XXXXXX")"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${FIRST_BROKER}" "sudo bash ${REMOTE_DIR}/generate_cluster_id.sh >/dev/null && sudo cat /etc/kafka/cluster.id" > "${TEMP_CLUSTER_ID}"
mv "${TEMP_CLUSTER_ID}" "${OUTPUT_DIR}/cluster.id"
TEMP_CLUSTER_ID=""

for i in "${!BROKER_IPS[@]}"; do
  NODE_ID=$((i + 1))
  HOST="${BROKER_IPS[$i]}"

  log "Configuring broker ${NODE_ID} at ${HOST}"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_scp_to "${HOST}" "${OUTPUT_DIR}/cluster.id"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo install -m 0644 -o kafka -g kafka ${REMOTE_DIR}/cluster.id /etc/kafka/cluster.id"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" \
    "sudo bash ${REMOTE_DIR}/configure_kafka_plaintext.sh ${NODE_ID} '${CONTROLLER_QUORUM_VOTERS}' ${HOST}"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo bash ${REMOTE_DIR}/create_systemd_service.sh"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo systemctl restart kafka"
  if ! wait_for_kafka_service "${HOST}"; then
    log "Kafka service failed health check on ${HOST}"
    exit 1
  fi
  printf 'BOOTSTRAPPED=true\nNODE_ID=%s\nHOST=%s\n' "${NODE_ID}" "${HOST}" > "${OUTPUT_DIR}/broker-${NODE_ID}.status"
done

for host in "${BROKER_IPS[@]}"; do
  log "Checking Kafka API readiness on ${host}"
  if ! wait_for_kafka_api "${host}"; then
    log "Kafka API readiness check failed on ${host}"
    exit 1
  fi
done

echo "Broker bootstrap complete."
