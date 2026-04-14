#!/usr/bin/env bash

set -euo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
METADATA_FILE="${METADATA_FILE:-${OUTPUT_DIR}/cluster.env}"

if [[ ! -f "${INVENTORY_FILE}" ]]; then
  echo "Missing inventory file at ${INVENTORY_FILE}"
  exit 1
fi

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"

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

QUORUM_VOTERS=""
for i in "${!BROKER_IPS[@]}"; do
  NODE_ID=$((i + 1))
  ENTRY="${NODE_ID}@${BROKER_IPS[$i]}:9093"
  if [[ -n "${QUORUM_VOTERS}" ]]; then
    QUORUM_VOTERS="${QUORUM_VOTERS},${ENTRY}"
  else
    QUORUM_VOTERS="${ENTRY}"
  fi
done

{
  echo "CONTROLLER_QUORUM_VOTERS=${QUORUM_VOTERS}"
  echo "BROKER_COUNT=${#BROKER_IPS[@]}"
} > "${METADATA_FILE}"

echo "Cluster metadata written to ${METADATA_FILE}"
