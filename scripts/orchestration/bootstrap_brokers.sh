#!/usr/bin/env bash

set -euo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
METADATA_FILE="${METADATA_FILE:-${OUTPUT_DIR}/cluster.env}"
SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
REMOTE_DIR="${REMOTE_DIR:-/tmp/kafka-bootstrap}"

if [[ -z "${SSH_KEY_PATH}" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

if [[ ! -f "${INVENTORY_FILE}" || ! -f "${METADATA_FILE}" ]]; then
  echo "Missing inventory or metadata file."
  exit 1
fi

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

for i in "${!BROKER_IPS[@]}"; do
  NODE_ID=$((i + 1))
  HOST="${BROKER_IPS[$i]}"

  ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${HOST}" "mkdir -p ${REMOTE_DIR}"
  scp -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no \
    deploy/kafka/bootstrap/install_kafka.sh \
    deploy/kafka/bootstrap/generate_cluster_id.sh \
    deploy/kafka/bootstrap/configure_kafka_plaintext.sh \
    deploy/kafka/bootstrap/create_systemd_service.sh \
    deploy/kafka/config/server.properties.plaintext.template \
    "${SSH_USER}@${HOST}:${REMOTE_DIR}/"

  ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${HOST}" "sudo bash ${REMOTE_DIR}/install_kafka.sh"
  ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${HOST}" "sudo cp ${REMOTE_DIR}/server.properties.plaintext.template /etc/kafka/server.properties.template"
done

FIRST_BROKER="${BROKER_IPS[0]}"
ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${FIRST_BROKER}" "sudo bash ${REMOTE_DIR}/generate_cluster_id.sh && sudo cat /etc/kafka/cluster.id" > "${OUTPUT_DIR}/cluster.id"

for i in "${!BROKER_IPS[@]}"; do
  NODE_ID=$((i + 1))
  HOST="${BROKER_IPS[$i]}"

  scp -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${OUTPUT_DIR}/cluster.id" "${SSH_USER}@${HOST}:${REMOTE_DIR}/cluster.id"
  ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${HOST}" "sudo cp ${REMOTE_DIR}/cluster.id /etc/kafka/cluster.id"
  ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${HOST}" \
    "sudo bash ${REMOTE_DIR}/configure_kafka_plaintext.sh ${NODE_ID} '${CONTROLLER_QUORUM_VOTERS}' ${HOST}"
  ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${HOST}" "sudo bash ${REMOTE_DIR}/create_systemd_service.sh"
  ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${HOST}" "sudo systemctl restart kafka"
done

echo "Broker bootstrap complete."
