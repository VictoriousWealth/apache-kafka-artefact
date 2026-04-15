#!/usr/bin/env bash

set -Eeuo pipefail

TF_DIR="${TF_DIR:-infrastructure/terraform/envs/dev}"
OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
TEMP_OUTPUT=""

cleanup() {
  if [[ -n "${TEMP_OUTPUT}" && -f "${TEMP_OUTPUT}" ]]; then
    rm -f "${TEMP_OUTPUT}"
  fi
}

trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}"

TEMP_OUTPUT="$(mktemp "${OUTPUT_DIR}/terraform-output.XXXXXX.json")"
terraform -chdir="${TF_DIR}" output -json > "${TEMP_OUTPUT}"
mv "${TEMP_OUTPUT}" "${OUTPUT_DIR}/terraform-output.json"
TEMP_OUTPUT=""

echo "Terraform outputs written to ${OUTPUT_DIR}/terraform-output.json"
