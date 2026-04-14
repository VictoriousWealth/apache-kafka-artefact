#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
CHECKPOINT_FILE="${CHECKPOINT_FILE:-${OUTPUT_DIR}/deploy_plaintext.checkpoints}"

step_export_outputs() {
  "${SCRIPT_DIR}/export_tf_outputs.sh"
}

step_build_inventory() {
  "${SCRIPT_DIR}/build_inventory.sh"
}

step_build_metadata() {
  "${SCRIPT_DIR}/build_cluster_metadata.sh"
}

step_prepare_client() {
  "${SCRIPT_DIR}/prepare_benchmark_client.sh"
}

step_bootstrap_brokers() {
  "${SCRIPT_DIR}/bootstrap_brokers.sh"
}

run_step() {
  local step_name="$1"
  shift

  if checkpoint_done "${CHECKPOINT_FILE}" "${step_name}"; then
    log "Skipping completed step: ${step_name}"
    return 0
  fi

  log "Running step: ${step_name}"
  "$@"
  mark_checkpoint "${CHECKPOINT_FILE}" "${step_name}"
}

mkdir -p "${OUTPUT_DIR}"

run_step "export_tf_outputs" step_export_outputs
run_step "build_inventory" step_build_inventory
run_step "build_cluster_metadata" step_build_metadata
run_step "prepare_benchmark_client" step_prepare_client
run_step "bootstrap_brokers" step_bootstrap_brokers

log "Plaintext cluster deployment flow completed."
