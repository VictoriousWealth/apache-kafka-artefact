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
REMOTE_DIR="${REMOTE_DIR:-/tmp/kafka-client-bootstrap}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_SLEEP_SECONDS="${RETRY_SLEEP_SECONDS:-5}"

if [[ -z "${SSH_KEY_PATH}" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

require_file "${INVENTORY_FILE}"

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"

if [[ -z "${BENCHMARK_CLIENT_IP:-}" ]]; then
  echo "BENCHMARK_CLIENT_IP not found in inventory."
  exit 1
fi

remote_ssh() {
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${BENCHMARK_CLIENT_IP}" "$@"
}

remote_scp() {
  scp "${SSH_OPTS[@]}" "$@" "${SSH_USER}@${BENCHMARK_CLIENT_IP}:${REMOTE_DIR}/"
}

run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "mkdir -p ${REMOTE_DIR}"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_scp \
  deploy/kafka/bootstrap/install_kafka_client.sh \
  deploy/kafka/client/plaintext-client.properties \
  deploy/kafka/client/run_plaintext_producer_perf.sh

run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "sudo bash ${REMOTE_DIR}/install_kafka_client.sh"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "sudo install -d -m 0755 /etc/kafka/client"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "sudo install -m 0644 ${REMOTE_DIR}/plaintext-client.properties /etc/kafka/client/plaintext-client.properties"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "sudo install -m 0755 ${REMOTE_DIR}/run_plaintext_producer_perf.sh /usr/local/bin/run_plaintext_producer_perf.sh"

log "Benchmark client prepared at ${BENCHMARK_CLIENT_IP}"
