#!/usr/bin/env bash

set -euo pipefail

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
TF_OUTPUT_JSON="${TF_OUTPUT_JSON:-${OUTPUT_DIR}/terraform-output.json}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"

if [[ ! -f "${TF_OUTPUT_JSON}" ]]; then
  echo "Missing Terraform output file at ${TF_OUTPUT_JSON}"
  exit 1
fi

BROKER_IPS="$(jq -r '.broker_public_ips.value[]' "${TF_OUTPUT_JSON}")"
CLIENT_IP="$(jq -r '.benchmark_client_public_ip.value' "${TF_OUTPUT_JSON}")"

{
  echo "BENCHMARK_CLIENT_IP=${CLIENT_IP}"
  i=1
  while IFS= read -r ip; do
    echo "BROKER_${i}_IP=${ip}"
    i=$((i + 1))
  done <<< "${BROKER_IPS}"
} > "${INVENTORY_FILE}"

echo "Inventory written to ${INVENTORY_FILE}"
