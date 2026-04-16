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

SUMMARY_LINES="$(grep -E 'records sent,.*records/sec' "${RAW_OUTPUT}" || true)"
if [[ -z "${SUMMARY_LINES}" ]]; then
  echo "Unable to find producer performance summary line in ${RAW_OUTPUT}"
  exit 1
fi

PARSED_METRICS="$(
  SUMMARY_LINES="${SUMMARY_LINES}" python3 - <<'PY'
import os, re, json
lines = [line for line in os.environ["SUMMARY_LINES"].splitlines() if line.strip()]
patterns = {
    "records_sent": r"^\s*([0-9]+)\s+records sent",
    "throughput_records_per_sec": r",\s*([0-9.]+)\s+records/sec",
    "throughput_mb_per_sec": r"\(\s*([0-9.]+)\s+MB/sec\)",
    "avg_latency_ms": r",\s*([0-9.]+)\s+ms avg latency",
    "max_latency_ms": r",\s*([0-9.]+)\s+ms max latency",
}
per_producer = []
for line in lines:
    data = {"summary_line": line}
    for key, pattern in patterns.items():
        match = re.search(pattern, line)
        data[key] = float(match.group(1)) if match and "." in match.group(1) else (int(match.group(1)) if match else None)
    per_producer.append(data)

records_sent = sum(item["records_sent"] or 0 for item in per_producer)
throughput_records_per_sec = sum(item["throughput_records_per_sec"] or 0 for item in per_producer)
throughput_mb_per_sec = sum(item["throughput_mb_per_sec"] or 0 for item in per_producer)
latency_weight = sum(item["records_sent"] or 0 for item in per_producer if item["avg_latency_ms"] is not None)
avg_latency_ms = None
if latency_weight:
    avg_latency_ms = sum((item["avg_latency_ms"] or 0) * (item["records_sent"] or 0) for item in per_producer) / latency_weight
max_values = [item["max_latency_ms"] for item in per_producer if item["max_latency_ms"] is not None]
print(json.dumps({
    "records_sent": records_sent,
    "throughput_records_per_sec": throughput_records_per_sec,
    "throughput_mb_per_sec": throughput_mb_per_sec,
    "avg_latency_ms": avg_latency_ms,
    "max_latency_ms": max(max_values) if max_values else None,
    "producer_summaries": per_producer,
}))
PY
)"

TEMP_RESULT="$(mktemp "${RUN_DIR}/result.XXXXXX.json")"
jq \
  --arg summary_lines "${SUMMARY_LINES}" \
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
      max_latency_ms: $parsed_metrics.max_latency_ms,
      producer_summaries: $parsed_metrics.producer_summaries
    },
    files: {
      raw_output: .raw_output,
      metadata: "metadata.json"
    },
    raw_summary_lines: ($summary_lines | split("\n"))
  }' \
  "${METADATA_JSON}" > "${TEMP_RESULT}"

mv "${TEMP_RESULT}" "${RESULT_JSON}"
TEMP_RESULT=""

echo "Structured result written to ${RESULT_JSON}"
