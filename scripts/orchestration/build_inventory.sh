#!/usr/bin/env bash

set -Eeuo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
TF_OUTPUT_JSON="${TF_OUTPUT_JSON:-${OUTPUT_DIR}/terraform-output.json}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
TEMP_INVENTORY=""

cleanup() {
  if [[ -n "${TEMP_INVENTORY}" && -f "${TEMP_INVENTORY}" ]]; then
    rm -f "${TEMP_INVENTORY}"
  fi
}

trap cleanup EXIT

if [[ ! -f "${TF_OUTPUT_JSON}" ]]; then
  echo "Missing Terraform output file at ${TF_OUTPUT_JSON}"
  exit 1
fi

BROKER_IPS="$(jq -r '.broker_public_ips.value[]' "${TF_OUTPUT_JSON}")"
CLIENT_IP="$(jq -r '.benchmark_client_public_ip.value' "${TF_OUTPUT_JSON}")"
TEMP_INVENTORY="$(mktemp "${OUTPUT_DIR}/inventory.XXXXXX.env")"

{
  echo "BENCHMARK_CLIENT_IP=${CLIENT_IP}"
  i=1
  while IFS= read -r ip; do
    echo "BROKER_${i}_IP=${ip}"
    i=$((i + 1))
  done <<< "${BROKER_IPS}"
} > "${TEMP_INVENTORY}"

mv "${TEMP_INVENTORY}" "${INVENTORY_FILE}"
TEMP_INVENTORY=""

echo "Inventory written to ${INVENTORY_FILE}"
