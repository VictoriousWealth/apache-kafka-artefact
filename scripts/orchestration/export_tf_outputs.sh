#!/usr/bin/env bash

set -euo pipefail

TF_DIR="${TF_DIR:-infrastructure/terraform/envs/dev}"
OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"

mkdir -p "${OUTPUT_DIR}"

terraform -chdir="${TF_DIR}" output -json > "${OUTPUT_DIR}/terraform-output.json"

echo "Terraform outputs written to ${OUTPUT_DIR}/terraform-output.json"
