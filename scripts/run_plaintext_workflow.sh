#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH_DIR="${SCRIPT_DIR}/orchestration"

SWEEP_FILE="${SWEEP_FILE:-config/sweeps/message_size_bytes.json}"

"${ORCH_DIR}/deploy_plaintext_cluster.sh"
"${ORCH_DIR}/run_parameter_sweep.sh"

echo "Plaintext workflow completed for sweep ${SWEEP_FILE}"
