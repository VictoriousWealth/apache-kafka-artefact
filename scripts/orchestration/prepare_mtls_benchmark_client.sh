#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
TLS_DIR="${TLS_DIR:-${OUTPUT_DIR}/tls}"
TLS_ENV="${TLS_ENV:-${TLS_DIR}/tls.env}"
SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
REMOTE_DIR="${REMOTE_DIR:-/tmp/kafka-client-bootstrap}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_SLEEP_SECONDS="${RETRY_SLEEP_SECONDS:-5}"

if [[ -z "${SSH_KEY_PATH}" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

require_file "${INVENTORY_FILE}"
require_file "${TLS_ENV}"
require_file "${TLS_DIR}/client/kafka.client.truststore.p12"
require_file "${TLS_DIR}/client/kafka.client.keystore.p12"

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"
# shellcheck disable=SC1090
source "${TLS_ENV}"

if [[ -z "${BENCHMARK_CLIENT_IP:-}" ]]; then
  echo "BENCHMARK_CLIENT_IP not found in inventory."
  exit 1
fi

SSH_OPTS=(-i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no -o ConnectTimeout=10)

remote_ssh() {
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${BENCHMARK_CLIENT_IP}" "$@"
}

remote_scp() {
  scp "${SSH_OPTS[@]}" "$@" "${SSH_USER}@${BENCHMARK_CLIENT_IP}:${REMOTE_DIR}/"
}

TEMP_CLIENT_PROPS="$(mktemp "${OUTPUT_DIR}/mtls-client.XXXXXX.properties")"
cleanup() {
  rm -f "${TEMP_CLIENT_PROPS}"
}
trap cleanup EXIT

sed "s|__TLS_STORE_PASSWORD__|${TLS_STORE_PASSWORD}|g" \
  deploy/kafka/client/mtls-client.properties.template > "${TEMP_CLIENT_PROPS}"

run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "mkdir -p ${REMOTE_DIR}"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_scp \
  "${TLS_DIR}/client/kafka.client.truststore.p12" \
  "${TLS_DIR}/client/kafka.client.keystore.p12" \
  "${TEMP_CLIENT_PROPS}"

run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "sudo install -d -m 0755 /etc/kafka/client/tls"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "sudo install -m 0640 ${REMOTE_DIR}/kafka.client.truststore.p12 /etc/kafka/client/tls/kafka.client.truststore.p12"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "sudo install -m 0640 ${REMOTE_DIR}/kafka.client.keystore.p12 /etc/kafka/client/tls/kafka.client.keystore.p12"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "sudo install -m 0640 ${REMOTE_DIR}/$(basename "${TEMP_CLIENT_PROPS}") /etc/kafka/client/mtls-client.properties"

log "mTLS benchmark client config installed at ${BENCHMARK_CLIENT_IP}"
