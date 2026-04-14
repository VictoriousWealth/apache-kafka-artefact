#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <sweep-results-directory>"
  exit 1
fi

SWEEP_DIR="$1"
SUMMARY_JSON="${SWEEP_DIR}/summary.json"
SUMMARY_CSV="${SWEEP_DIR}/summary.csv"
TEMP_JSON=""
TEMP_CSV=""

cleanup() {
  if [[ -n "${TEMP_JSON}" && -f "${TEMP_JSON}" ]]; then
    rm -f "${TEMP_JSON}"
  fi
  if [[ -n "${TEMP_CSV}" && -f "${TEMP_CSV}" ]]; then
    rm -f "${TEMP_CSV}"
  fi
}

trap cleanup EXIT

if [[ ! -d "${SWEEP_DIR}" ]]; then
  echo "Sweep results directory not found: ${SWEEP_DIR}"
  exit 1
fi

mapfile -t RESULT_FILES < <(find "${SWEEP_DIR}" -mindepth 2 -maxdepth 2 -type f -name result.json | sort)

if [[ "${#RESULT_FILES[@]}" -eq 0 ]]; then
  echo "No result.json files found under ${SWEEP_DIR}"
  exit 1
fi

TEMP_JSON="$(mktemp "${SWEEP_DIR}/summary.XXXXXX.json")"
TEMP_CSV="$(mktemp "${SWEEP_DIR}/summary.XXXXXX.csv")"

jq -s '
  {
    schema_version: "1.0",
    sweep_name: .[0].sweep_name,
    baseline_name: .[0].baseline_name,
    sweep_variable: .[0].sweep_variable,
    run_count: length,
    security_modes: ([.[].security_mode] | unique),
    values_tested: ([.[].sweep_value] | unique),
    runs: [
      .[] | {
        run_id,
        security_mode,
        baseline_name,
        sweep_name,
        sweep_variable,
        sweep_value,
        broker_count: .cluster.broker_count,
        partitions: .cluster.partitions,
        replication_factor: .cluster.replication_factor,
        num_records: .run_config.num_records,
        record_size_bytes: .run_config.record_size_bytes,
        throughput_limit_records_per_sec: .run_config.throughput_limit_records_per_sec,
        producer_count: .run_config.producer_count,
        consumer_count: .run_config.consumer_count,
        batch_size: .run_config.batch_size,
        linger_ms: .run_config.linger_ms,
        acks: .run_config.acks,
        records_sent: .metrics.records_sent,
        throughput_records_per_sec: .metrics.throughput_records_per_sec,
        throughput_mb_per_sec: .metrics.throughput_mb_per_sec,
        avg_latency_ms: .metrics.avg_latency_ms,
        max_latency_ms: .metrics.max_latency_ms
      }
    ]
  }' "${RESULT_FILES[@]}" > "${TEMP_JSON}"

jq -r '
  [
    "run_id",
    "security_mode",
    "baseline_name",
    "sweep_name",
    "sweep_variable",
    "sweep_value",
    "broker_count",
    "partitions",
    "replication_factor",
    "num_records",
    "record_size_bytes",
    "throughput_limit_records_per_sec",
    "producer_count",
    "consumer_count",
    "batch_size",
    "linger_ms",
    "acks",
    "records_sent",
    "throughput_records_per_sec",
    "throughput_mb_per_sec",
    "avg_latency_ms",
    "max_latency_ms"
  ],
  (
    .runs[] |
    [
      .run_id,
      .security_mode,
      .baseline_name,
      .sweep_name,
      .sweep_variable,
      (.sweep_value | tostring),
      (.broker_count | tostring),
      (.partitions | tostring),
      (.replication_factor | tostring),
      (.num_records | tostring),
      (.record_size_bytes | tostring),
      (.throughput_limit_records_per_sec | tostring),
      (.producer_count | tostring),
      (.consumer_count | tostring),
      (.batch_size | tostring),
      (.linger_ms | tostring),
      .acks,
      (.records_sent | tostring),
      (.throughput_records_per_sec | tostring),
      (.throughput_mb_per_sec | tostring),
      (.avg_latency_ms | tostring),
      (.max_latency_ms | tostring)
    ]
  ) | @csv' "${TEMP_JSON}" > "${TEMP_CSV}"

mv "${TEMP_JSON}" "${SUMMARY_JSON}"
mv "${TEMP_CSV}" "${SUMMARY_CSV}"
TEMP_JSON=""
TEMP_CSV=""

echo "Sweep summary written to ${SUMMARY_JSON} and ${SUMMARY_CSV}"
