#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
METADATA_FILE="${METADATA_FILE:-${OUTPUT_DIR}/cluster.env}"
TLS_DIR="${TLS_DIR:-${OUTPUT_DIR}/tls}"
TLS_ENV="${TLS_ENV:-${TLS_DIR}/tls.env}"
SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
REMOTE_DIR="${REMOTE_DIR:-/tmp/kafka-bootstrap}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_SLEEP_SECONDS="${RETRY_SLEEP_SECONDS:-5}"
RESET_KAFKA_STORAGE="${RESET_KAFKA_STORAGE:-true}"

if [[ -z "${SSH_KEY_PATH}" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

require_file "${INVENTORY_FILE}"
require_file "${METADATA_FILE}"
require_file "${TLS_ENV}"

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"
# shellcheck disable=SC1090
source "${METADATA_FILE}"
# shellcheck disable=SC1090
source "${TLS_ENV}"

SSH_OPTS=(-i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no -o ConnectTimeout=10)

BROKER_PUBLIC_IPS=()
BROKER_PRIVATE_IPS=()
INDEX=1
while true; do
  VAR_NAME="BROKER_${INDEX}_IP"
  if [[ -z "${!VAR_NAME:-}" ]]; then
    break
  fi
  BROKER_PUBLIC_IPS+=("${!VAR_NAME}")
  PRIVATE_VAR_NAME="BROKER_${INDEX}_PRIVATE_IP"
  if [[ -z "${!PRIVATE_VAR_NAME:-}" ]]; then
    echo "Missing ${PRIVATE_VAR_NAME} in inventory."
    exit 1
  fi
  BROKER_PRIVATE_IPS+=("${!PRIVATE_VAR_NAME}")
  require_file "${TLS_DIR}/brokers/broker-${INDEX}/kafka.server.keystore.p12"
  require_file "${TLS_DIR}/brokers/broker-${INDEX}/kafka.server.truststore.p12"
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

reset_kafka_storage() {
  local host="$1"
  remote_ssh "${host}" "sudo systemctl stop kafka >/dev/null 2>&1 || true; sudo mkdir -p /var/lib/kafka/data; sudo find /var/lib/kafka/data -mindepth 1 -maxdepth 1 -exec rm -rf {} +; sudo chown -R kafka:kafka /var/lib/kafka/data"
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

wait_for_kafka_tls_api() {
  local host="$1"
  local bootstrap_host="$2"
  local attempt=1
  local remote_cmd="sudo /opt/kafka_2.13-3.8.0/bin/kafka-broker-api-versions.sh --bootstrap-server ${bootstrap_host}:9094 --command-config /etc/kafka/tls/tls-client.properties >/dev/null 2>&1"
  while (( attempt <= MAX_RETRIES )); do
    if remote_ssh "${host}" "${remote_cmd}"; then
      return 0
    fi
    sleep "${RETRY_SLEEP_SECONDS}"
    attempt=$((attempt + 1))
  done
  return 1
}

TEMP_CLUSTER_ID="$(mktemp "${OUTPUT_DIR}/cluster.id.XXXXXX")"
TEMP_TLS_CLIENT_PROPS="$(mktemp "${OUTPUT_DIR}/broker-tls-client.XXXXXX.properties")"
cleanup() {
  rm -f "${TEMP_CLUSTER_ID}" "${TEMP_TLS_CLIENT_PROPS}"
}
trap cleanup EXIT

sed "s|__TLS_STORE_PASSWORD__|${TLS_STORE_PASSWORD}|g" \
  deploy/kafka/client/tls-client.properties.template |
  sed "s|/etc/kafka/client/tls/kafka.client.truststore.p12|/etc/kafka/tls/kafka.server.truststore.p12|g" \
  > "${TEMP_TLS_CLIENT_PROPS}"

for i in "${!BROKER_PUBLIC_IPS[@]}"; do
  HOST="${BROKER_PUBLIC_IPS[$i]}"
  NODE_ID=$((i + 1))

  log "Preparing TLS broker host ${HOST}"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "mkdir -p ${REMOTE_DIR}"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_scp_to "${HOST}" \
    deploy/kafka/bootstrap/install_kafka.sh \
    deploy/kafka/bootstrap/generate_cluster_id.sh \
    deploy/kafka/bootstrap/configure_kafka_tls.sh \
    deploy/kafka/bootstrap/create_systemd_service.sh \
    deploy/kafka/common/collect_host_telemetry.sh \
    deploy/kafka/config/server.properties.tls.template \
    "${TLS_DIR}/brokers/broker-${NODE_ID}/kafka.server.keystore.p12" \
    "${TLS_DIR}/brokers/broker-${NODE_ID}/kafka.server.truststore.p12" \
    "${TEMP_TLS_CLIENT_PROPS}"

  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo bash ${REMOTE_DIR}/install_kafka.sh"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo install -m 0755 ${REMOTE_DIR}/collect_host_telemetry.sh /usr/local/bin/collect_host_telemetry.sh"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo install -d -m 0750 -o kafka -g kafka /etc/kafka/tls"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo install -m 0640 -o kafka -g kafka ${REMOTE_DIR}/kafka.server.keystore.p12 /etc/kafka/tls/kafka.server.keystore.p12"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo install -m 0640 -o kafka -g kafka ${REMOTE_DIR}/kafka.server.truststore.p12 /etc/kafka/tls/kafka.server.truststore.p12"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo install -m 0640 -o kafka -g kafka ${REMOTE_DIR}/$(basename "${TEMP_TLS_CLIENT_PROPS}") /etc/kafka/tls/tls-client.properties"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo install -m 0644 -o kafka -g kafka ${REMOTE_DIR}/server.properties.tls.template /etc/kafka/server.properties.template"
done

FIRST_BROKER="${BROKER_PUBLIC_IPS[0]}"
run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${FIRST_BROKER}" "sudo bash ${REMOTE_DIR}/generate_cluster_id.sh >/dev/null && sudo cat /etc/kafka/cluster.id" > "${TEMP_CLUSTER_ID}"
mv "${TEMP_CLUSTER_ID}" "${OUTPUT_DIR}/cluster.id"
TEMP_CLUSTER_ID=""
TEMP_CLUSTER_ID=""

for i in "${!BROKER_PUBLIC_IPS[@]}"; do
  NODE_ID=$((i + 1))
  HOST="${BROKER_PUBLIC_IPS[$i]}"
  KAFKA_HOST="${BROKER_PRIVATE_IPS[$i]}"

  log "Configuring TLS broker ${NODE_ID} at ${HOST}"
  if [[ "${RESET_KAFKA_STORAGE}" == "true" ]]; then
    log "Resetting Kafka storage on broker ${NODE_ID}"
    run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" reset_kafka_storage "${HOST}"
  fi
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_scp_to "${HOST}" "${OUTPUT_DIR}/cluster.id"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo install -m 0644 -o kafka -g kafka ${REMOTE_DIR}/cluster.id /etc/kafka/cluster.id"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" \
    "sudo bash ${REMOTE_DIR}/configure_kafka_tls.sh ${NODE_ID} '${CONTROLLER_QUORUM_VOTERS}' ${KAFKA_HOST} '${TLS_STORE_PASSWORD}'"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo bash ${REMOTE_DIR}/create_systemd_service.sh"
done

for i in "${!BROKER_PUBLIC_IPS[@]}"; do
  NODE_ID=$((i + 1))
  HOST="${BROKER_PUBLIC_IPS[$i]}"
  KAFKA_HOST="${BROKER_PRIVATE_IPS[$i]}"

  log "Restarting TLS broker ${NODE_ID} at ${HOST}"
  run_with_retries "${MAX_RETRIES}" "${RETRY_SLEEP_SECONDS}" remote_ssh "${HOST}" "sudo systemctl restart kafka"
  printf 'CONFIGURED=true\nSECURITY_MODE=tls\nNODE_ID=%s\nHOST=%s\nKAFKA_HOST=%s\n' "${NODE_ID}" "${HOST}" "${KAFKA_HOST}" > "${OUTPUT_DIR}/broker-${NODE_ID}.status"
done

for i in "${!BROKER_PUBLIC_IPS[@]}"; do
  NODE_ID=$((i + 1))
  HOST="${BROKER_PUBLIC_IPS[$i]}"
  if ! wait_for_kafka_service "${HOST}"; then
    log "Kafka TLS service failed health check on ${HOST}"
    exit 1
  fi
  printf 'BOOTSTRAPPED=true\nSECURITY_MODE=tls\nNODE_ID=%s\nHOST=%s\nKAFKA_HOST=%s\n' "${NODE_ID}" "${HOST}" "${BROKER_PRIVATE_IPS[$i]}" > "${OUTPUT_DIR}/broker-${NODE_ID}.status"
done

for i in "${!BROKER_PUBLIC_IPS[@]}"; do
  HOST="${BROKER_PUBLIC_IPS[$i]}"
  KAFKA_HOST="${BROKER_PRIVATE_IPS[$i]}"
  log "Checking Kafka TLS API readiness on ${KAFKA_HOST}:9094"
  if ! wait_for_kafka_tls_api "${HOST}" "${KAFKA_HOST}"; then
    log "Kafka TLS API readiness check failed on ${KAFKA_HOST}:9094"
    exit 1
  fi
done

echo "TLS broker bootstrap complete."
