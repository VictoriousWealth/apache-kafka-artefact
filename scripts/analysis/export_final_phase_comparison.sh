#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: export_final_phase_comparison.sh --broker-count <3|5> [--results-root <dir>] [--output-dir <dir>]

Exports matched plaintext/TLS/mTLS security-overhead comparison artefacts for a canonical
final campaign broker-count phase.

Defaults:
  --results-root results/factorial-final
  --output-dir   <results-root>/security-overhead-final-broker<broker-count>-comparison

Expected input summaries:
  <results-root>/security-overhead-final-plaintext-broker<broker-count>/summary.csv
  <results-root>/security-overhead-final-tls-broker<broker-count>/summary.csv
  <results-root>/security-overhead-final-mtls-broker<broker-count>/summary.csv
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_ROOT="results/factorial-final"
OUTPUT_DIR=""
BROKER_COUNT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --broker-count)
      BROKER_COUNT="$2"
      shift 2
      ;;
    --results-root)
      RESULTS_ROOT="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${BROKER_COUNT}" != "3" && "${BROKER_COUNT}" != "5" ]]; then
  echo "Set --broker-count to 3 or 5." >&2
  usage >&2
  exit 1
fi

if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="${RESULTS_ROOT}/security-overhead-final-broker${BROKER_COUNT}-comparison"
fi

PLAINTEXT_SUMMARY="${RESULTS_ROOT}/security-overhead-final-plaintext-broker${BROKER_COUNT}/summary.csv"
TLS_SUMMARY="${RESULTS_ROOT}/security-overhead-final-tls-broker${BROKER_COUNT}/summary.csv"
MTLS_SUMMARY="${RESULTS_ROOT}/security-overhead-final-mtls-broker${BROKER_COUNT}/summary.csv"

missing=0
for summary in "${PLAINTEXT_SUMMARY}" "${TLS_SUMMARY}" "${MTLS_SUMMARY}"; do
  if [[ ! -f "${summary}" ]]; then
    echo "Missing required summary: ${summary}" >&2
    missing=1
  fi
done

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

"${SCRIPT_DIR}/export_security_comparison.sh" \
  "${OUTPUT_DIR}" \
  "${PLAINTEXT_SUMMARY}" \
  "${TLS_SUMMARY}" \
  "${MTLS_SUMMARY}"
