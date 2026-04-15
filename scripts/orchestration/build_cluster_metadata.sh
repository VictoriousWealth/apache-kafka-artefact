#!/usr/bin/env bash

set -Eeuo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
METADATA_FILE="${METADATA_FILE:-${OUTPUT_DIR}/cluster.env}"
TEMP_METADATA=""

cleanup() {
  if [[ -n "${TEMP_METADATA}" && -f "${TEMP_METADATA}" ]]; then
    rm -f "${TEMP_METADATA}"
  fi
}

trap cleanup EXIT

if [[ ! -f "${INVENTORY_FILE}" ]]; then
  echo "Missing inventory file at ${INVENTORY_FILE}"
  exit 1
fi

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"

BROKER_PRIVATE_IPS=()
INDEX=1
while true; do
  VAR_NAME="BROKER_${INDEX}_PRIVATE_IP"
  if [[ -z "${!VAR_NAME:-}" ]]; then
    break
  fi
  BROKER_PRIVATE_IPS+=("${!VAR_NAME}")
  INDEX=$((INDEX + 1))
done

if [[ "${#BROKER_PRIVATE_IPS[@]}" -eq 0 ]]; then
  echo "No broker private IPs found in inventory."
  exit 1
fi

TEMP_METADATA="$(mktemp "${OUTPUT_DIR}/cluster.XXXXXX.env")"
QUORUM_VOTERS=""
BOOTSTRAP_SERVERS=""
for i in "${!BROKER_PRIVATE_IPS[@]}"; do
  NODE_ID=$((i + 1))
  ENTRY="${NODE_ID}@${BROKER_PRIVATE_IPS[$i]}:9093"
  if [[ -n "${QUORUM_VOTERS}" ]]; then
    QUORUM_VOTERS="${QUORUM_VOTERS},${ENTRY}"
  else
    QUORUM_VOTERS="${ENTRY}"
  fi
  if [[ -n "${BOOTSTRAP_SERVERS}" ]]; then
    BOOTSTRAP_SERVERS="${BOOTSTRAP_SERVERS},${BROKER_PRIVATE_IPS[$i]}:9092"
  else
    BOOTSTRAP_SERVERS="${BROKER_PRIVATE_IPS[$i]}:9092"
  fi
done

{
  echo "CONTROLLER_QUORUM_VOTERS=${QUORUM_VOTERS}"
  echo "BOOTSTRAP_SERVERS=${BOOTSTRAP_SERVERS}"
  echo "BROKER_COUNT=${#BROKER_PRIVATE_IPS[@]}"
} > "${TEMP_METADATA}"

mv "${TEMP_METADATA}" "${METADATA_FILE}"
TEMP_METADATA=""

echo "Cluster metadata written to ${METADATA_FILE}"
