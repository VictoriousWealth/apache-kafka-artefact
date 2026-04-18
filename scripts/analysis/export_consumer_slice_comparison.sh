#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: export_consumer_slice_comparison.sh [--broker-count <5>] [--results-root <dir>] [--output-dir <dir>]

Exports matched plaintext/TLS/mTLS comparison artefacts for the targeted consumer-side
security slice.

Defaults:
  --broker-count 5
  --results-root results/consumer-slice
  --output-dir   <results-root>/consumer-security-slice-broker<broker-count>-comparison

Expected input summaries:
  <results-root>/consumer-security-slice-plaintext-broker<broker-count>/summary.csv
  <results-root>/consumer-security-slice-tls-broker<broker-count>/summary.csv
  <results-root>/consumer-security-slice-mtls-broker<broker-count>/summary.csv
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_ROOT="results/consumer-slice"
OUTPUT_DIR=""
BROKER_COUNT="5"

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

if [[ "${BROKER_COUNT}" != "5" ]]; then
  echo "The current consumer-security-slice config is defined for broker-count 5 only." >&2
  exit 1
fi

if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="${RESULTS_ROOT}/consumer-security-slice-broker${BROKER_COUNT}-comparison"
fi

PLAINTEXT_SUMMARY="${RESULTS_ROOT}/consumer-security-slice-plaintext-broker${BROKER_COUNT}/summary.csv"
TLS_SUMMARY="${RESULTS_ROOT}/consumer-security-slice-tls-broker${BROKER_COUNT}/summary.csv"
MTLS_SUMMARY="${RESULTS_ROOT}/consumer-security-slice-mtls-broker${BROKER_COUNT}/summary.csv"

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
