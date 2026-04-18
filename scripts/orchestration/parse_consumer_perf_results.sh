#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <run-directory>"
  exit 1
fi

RUN_DIR="$1"
RAW_OUTPUT="${RUN_DIR}/consumer-perf.log"
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
  echo "Missing raw consumer output at ${RAW_OUTPUT}"
  exit 1
fi

if [[ ! -f "${METADATA_JSON}" ]]; then
  echo "Missing metadata file at ${METADATA_JSON}"
  exit 1
fi

PARSED_METRICS="$(
  RAW_OUTPUT="${RAW_OUTPUT}" python3 - <<'PY'
import csv
import json
import os

path = os.environ["RAW_OUTPUT"]
rows = []
with open(path, "r", encoding="utf-8") as handle:
    reader = csv.DictReader(line for line in handle if line.strip() and not line.startswith("WARNING"))
    for row in reader:
        rows.append({key.strip(): value.strip() for key, value in row.items() if key is not None})

def number(row, *names):
    for name in names:
        if name in row and row[name] != "":
            try:
                return float(row[name])
            except ValueError:
                return None
    return None

summary = rows[-1] if rows else {}
print(json.dumps({
    "records_consumed": number(summary, "data.consumed.in.nMsg", "data.consumed.in.nMsg "),
    "throughput_records_per_sec": number(summary, "nMsg.sec", "fetch.nMsg.sec"),
    "throughput_mb_per_sec": number(summary, "MB.sec", "fetch.MB.sec"),
    "data_consumed_mb": number(summary, "data.consumed.in.MB"),
    "rebalance_time_ms": number(summary, "rebalance.time.ms"),
    "fetch_time_ms": number(summary, "fetch.time.ms"),
    "raw_rows": rows,
}))
PY
)"

TEMP_RESULT="$(mktemp "${RUN_DIR}/result.XXXXXX.json")"
jq \
  --argjson parsed_metrics "${PARSED_METRICS}" \
  '{
    schema_version: "1.0",
    benchmark_type: "consumer",
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
      producer_throughput_limit_records_per_sec: .producer_throughput_limit,
      producer_count: .producer_count,
      consumer_count: .consumer_count,
      batch_size: .batch_size,
      linger_ms: .linger_ms,
      acks: .acks,
      compression_type: (.compression_type // "none")
    },
    metrics: $parsed_metrics,
    files: {
      raw_output: .raw_output,
      producer_seed_output: .producer_seed_output,
      metadata: "metadata.json"
    }
  }' \
  "${METADATA_JSON}" > "${TEMP_RESULT}"

mv "${TEMP_RESULT}" "${RESULT_JSON}"
TEMP_RESULT=""

echo "Structured consumer result written to ${RESULT_JSON}"
