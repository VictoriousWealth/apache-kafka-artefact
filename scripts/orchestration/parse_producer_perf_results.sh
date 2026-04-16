#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <run-directory>"
  exit 1
fi

RUN_DIR="$1"
RAW_OUTPUT="${RUN_DIR}/producer-perf.log"
METADATA_JSON="${RUN_DIR}/metadata.json"
RESULT_JSON="${RUN_DIR}/result.json"
TEMP_RESULT=""

cleanup() {
  if [[ -n "${TEMP_RESULT}" && -f "${TEMP_RESULT}" ]]; then
    rm -f "${TEMP_RESULT}"
  fi
}

trap cleanup EXIT

if [[ ! -f "${RAW_OUTPUT}" ]]; then
  echo "Missing raw producer output at ${RAW_OUTPUT}"
  exit 1
fi

if [[ ! -f "${METADATA_JSON}" ]]; then
  echo "Missing metadata file at ${METADATA_JSON}"
  exit 1
fi

SUMMARY_LINE="$(grep -E 'records sent,.*records/sec' "${RAW_OUTPUT}" | tail -n 1 || true)"
if [[ -z "${SUMMARY_LINE}" ]]; then
  echo "Unable to find producer performance summary line in ${RAW_OUTPUT}"
  exit 1
fi

PARSED_METRICS="$(
  SUMMARY_LINE="${SUMMARY_LINE}" python3 - <<'PY'
import os, re, json, sys
line = os.environ["SUMMARY_LINE"]
patterns = {
    "records_sent": r"^\s*([0-9]+)\s+records sent",
    "throughput_records_per_sec": r",\s*([0-9.]+)\s+records/sec",
    "throughput_mb_per_sec": r"\(\s*([0-9.]+)\s+MB/sec\)",
    "avg_latency_ms": r",\s*([0-9.]+)\s+ms avg latency",
    "max_latency_ms": r",\s*([0-9.]+)\s+ms max latency",
}
data = {}
for key, pattern in patterns.items():
    match = re.search(pattern, line)
    data[key] = float(match.group(1)) if match and "." in match.group(1) else (int(match.group(1)) if match else None)
print(json.dumps(data))
PY
)"

TEMP_RESULT="$(mktemp "${RUN_DIR}/result.XXXXXX.json")"
jq \
  --arg summary_line "${SUMMARY_LINE}" \
  --argjson parsed_metrics "${PARSED_METRICS}" \
  '{
    schema_version: "1.0",
    run_id: .run_id,
    security_mode: .security_mode,
    baseline_name: .baseline_name,
    sweep_name: .sweep_name,
    sweep_variable: .sweep_variable,
    sweep_value: .sweep_value,
    trial_index: .trial_index,
    trial_count: .trial_count,
    topic: .topic,
    cluster: {
      bootstrap_servers: .bootstrap_servers,
      broker_count: .broker_count,
      partitions: .partitions,
      replication_factor: .replication_factor,
      min_insync_replicas: (.min_insync_replicas // null)
    },
    run_config: {
      num_records: .num_records,
      record_size_bytes: .record_size,
      throughput_limit_records_per_sec: .throughput_limit,
      producer_count: .producer_count,
      consumer_count: .consumer_count,
      batch_size: .batch_size,
      linger_ms: .linger_ms,
      acks: .acks,
      compression_type: (.compression_type // "none")
    },
    metrics: {
      records_sent: $parsed_metrics.records_sent,
      throughput_records_per_sec: $parsed_metrics.throughput_records_per_sec,
      throughput_mb_per_sec: $parsed_metrics.throughput_mb_per_sec,
      avg_latency_ms: $parsed_metrics.avg_latency_ms,
      max_latency_ms: $parsed_metrics.max_latency_ms
    },
    files: {
      raw_output: .raw_output,
      metadata: "metadata.json"
    },
    raw_summary_line: $summary_line
  }' \
  "${METADATA_JSON}" > "${TEMP_RESULT}"

mv "${TEMP_RESULT}" "${RESULT_JSON}"
TEMP_RESULT=""

echo "Structured result written to ${RESULT_JSON}"
