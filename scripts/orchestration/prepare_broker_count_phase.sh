#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [broker-count]"
  echo "Set TARGET_BROKER_COUNT or pass 3/5 as the first argument."
  exit 1
fi

TARGET_BROKER_COUNT="${1:-${TARGET_BROKER_COUNT:-}}"
TF_DIR="${TF_DIR:-infrastructure/terraform/envs/dev}"
TFVARS_FILE="${TFVARS_FILE:-${TF_DIR}/terraform.tfvars}"
OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
PHASE_FILE="${PHASE_FILE:-${OUTPUT_DIR}/broker-count-phase.env}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
CONFIRM_DESTROY_EXTRA_BROKERS="${CONFIRM_DESTROY_EXTRA_BROKERS:-false}"
RESET_KAFKA_STORAGE="${RESET_KAFKA_STORAGE:-true}"
PLAN_ONLY="${PLAN_ONLY:-false}"

if [[ "${TARGET_BROKER_COUNT}" != "3" && "${TARGET_BROKER_COUNT}" != "5" ]]; then
  echo "TARGET_BROKER_COUNT must be 3 or 5."
  exit 1
fi

if [[ -z "${SSH_KEY_PATH}" && "${PLAN_ONLY}" != "true" ]]; then
  echo "Set SSH_KEY_PATH to your private key."
  exit 1
fi

require_file "${TFVARS_FILE}"

terraform_output_broker_count() {
  terraform -chdir="${TF_DIR}" output -json broker_private_ips 2>/dev/null | jq 'length' 2>/dev/null || true
}

tfvars_broker_count() {
  awk '$1 == "broker_count" {print $3}' "${TFVARS_FILE}" | tail -n 1
}

write_tfvars_broker_count() {
  local target_count="$1"
  local temp_file
  temp_file="$(mktemp "$(dirname "${TFVARS_FILE}")/terraform.XXXXXX.tfvars")"
  awk -v target_count="${target_count}" '
    BEGIN { updated = 0 }
    $1 == "broker_count" {
      print "broker_count      = " target_count
      updated = 1
      next
    }
    { print }
    END {
      if (updated == 0) {
        print "broker_count      = " target_count
      }
    }
  ' "${TFVARS_FILE}" > "${temp_file}"
  mv "${temp_file}" "${TFVARS_FILE}"
}

write_phase_file() {
  local temp_file
  temp_file="$(mktemp "${OUTPUT_DIR}/broker-count-phase.XXXXXX.env")"
  {
    echo "BROKER_COUNT_PHASE=${TARGET_BROKER_COUNT}"
    echo "RESET_KAFKA_STORAGE=${RESET_KAFKA_STORAGE}"
    echo "PHASE_PREPARED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  } > "${temp_file}"
  mv "${temp_file}" "${PHASE_FILE}"
}

mkdir -p "${OUTPUT_DIR}"

CURRENT_BROKER_COUNT="$(terraform_output_broker_count)"
if [[ -z "${CURRENT_BROKER_COUNT}" || "${CURRENT_BROKER_COUNT}" == "null" ]]; then
  CURRENT_BROKER_COUNT="$(tfvars_broker_count)"
fi

if [[ -z "${CURRENT_BROKER_COUNT}" ]]; then
  echo "Unable to determine current broker count."
  exit 1
fi

if (( TARGET_BROKER_COUNT < CURRENT_BROKER_COUNT )) && [[ "${CONFIRM_DESTROY_EXTRA_BROKERS}" != "true" ]]; then
  cat <<EOF
Refusing to shrink broker count from ${CURRENT_BROKER_COUNT} to ${TARGET_BROKER_COUNT}.

Terraform will destroy extra broker instances for this transition.
If this is intentional, rerun with:

  CONFIRM_DESTROY_EXTRA_BROKERS=true

EOF
  exit 1
fi

log "Preparing broker-count phase ${TARGET_BROKER_COUNT}; current broker count appears to be ${CURRENT_BROKER_COUNT}"
write_tfvars_broker_count "${TARGET_BROKER_COUNT}"

if [[ "${PLAN_ONLY}" == "true" ]]; then
  terraform -chdir="${TF_DIR}" plan
  exit 0
fi

terraform -chdir="${TF_DIR}" apply -auto-approve

"${SCRIPT_DIR}/export_tf_outputs.sh"
"${SCRIPT_DIR}/build_inventory.sh"
"${SCRIPT_DIR}/build_cluster_metadata.sh"

RESET_KAFKA_STORAGE="${RESET_KAFKA_STORAGE}" SSH_KEY_PATH="${SSH_KEY_PATH}" "${SCRIPT_DIR}/bootstrap_brokers.sh"
SSH_KEY_PATH="${SSH_KEY_PATH}" "${SCRIPT_DIR}/prepare_benchmark_client.sh"

write_phase_file

log "Broker-count phase ${TARGET_BROKER_COUNT} prepared. Phase marker written to ${PHASE_FILE}"
