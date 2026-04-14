#!/usr/bin/env bash

set -Eeuo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
SSH_USER="${SSH_USER:-ubuntu}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
SSH_OPTS=(-i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no -o ConnectTimeout=10)

if [[ -z "${SSH_KEY_PATH}" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

if [[ ! -f "${INVENTORY_FILE}" ]]; then
  echo "Missing inventory file at ${INVENTORY_FILE}"
  exit 1
fi

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"

if [[ -z "${BENCHMARK_CLIENT_IP:-}" ]]; then
  echo "BENCHMARK_CLIENT_IP not found in inventory."
  exit 1
fi

ssh "${SSH_OPTS[@]}" "${SSH_USER}@${BENCHMARK_CLIENT_IP}" \
  "sudo apt-get update && sudo apt-get install -y openjdk-17-jre-headless wget tar jq"

echo "Benchmark client prepared at ${BENCHMARK_CLIENT_IP}"
