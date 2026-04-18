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
TELEMETRY_DIR="${RUN_DIR}/host-telemetry"
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

SUMMARY_LINES=""
while IFS= read -r producer_log; do
  producer_summary="$(grep -E 'records sent,.*records/sec' "${producer_log}" | tail -n 1 || true)"
  if [[ -n "${producer_summary}" ]]; then
    if [[ -n "${SUMMARY_LINES}" ]]; then
      SUMMARY_LINES+=$'\n'
    fi
    SUMMARY_LINES+="${producer_summary}"
  fi
done < <(find "${RUN_DIR}" -maxdepth 1 -type f -name 'producer-perf-[0-9]*.log' | sort)

if [[ -z "${SUMMARY_LINES}" ]]; then
  SUMMARY_LINES="$(grep -E 'records sent,.*records/sec' "${RAW_OUTPUT}" | tail -n 1 || true)"
fi

if [[ -z "${SUMMARY_LINES}" ]]; then
  echo "Unable to find producer performance summary line in ${RAW_OUTPUT}"
  exit 1
fi

PARSED_METRICS="$(
  SUMMARY_LINES="${SUMMARY_LINES}" RUN_DIR="${RUN_DIR}" python3 - <<'PY'
import glob
import math
import os
import re
import json

lines = [line for line in os.environ["SUMMARY_LINES"].splitlines() if line.strip()]
run_dir = os.environ["RUN_DIR"]
patterns = {
    "records_sent": r"^\s*([0-9]+)\s+records sent",
    "throughput_records_per_sec": r",\s*([0-9.]+)\s+records/sec",
    "throughput_mb_per_sec": r"\(\s*([0-9.]+)\s+MB/sec\)",
    "avg_latency_ms": r",\s*([0-9.]+)\s+ms avg latency",
    "max_latency_ms": r",\s*([0-9.]+)\s+ms max latency",
}

def parse_summary_line(line):
    data = {"summary_line": line}
    for key, pattern in patterns.items():
        match = re.search(pattern, line)
        data[key] = float(match.group(1)) if match and "." in match.group(1) else (int(match.group(1)) if match else None)
    return data

def percentile(values, percentile_value):
    values = sorted(value for value in values if value is not None)
    if not values:
        return None
    if len(values) == 1:
        return values[0]
    rank = (len(values) - 1) * (percentile_value / 100.0)
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return values[int(rank)]
    return values[lower] + ((values[upper] - values[lower]) * (rank - lower))

per_producer = []
for line in lines:
    per_producer.append(parse_summary_line(line))

interval_summaries = []
for producer_log in sorted(glob.glob(os.path.join(run_dir, "producer-perf-[0-9]*.log"))):
    producer_index = None
    producer_count = None
    with open(producer_log, "r", encoding="utf-8") as handle:
        matched_lines = []
        for raw_line in handle:
            line = raw_line.strip()
            if line.startswith("producer_index="):
                producer_index = int(line.split("=", 1)[1])
                continue
            if line.startswith("producer_count="):
                producer_count = int(line.split("=", 1)[1])
                continue
            if re.search(r"records sent,.*records/sec", line):
                matched_lines.append(line)

    # kafka-producer-perf-test prints periodic interval lines and a final summary line.
    # Drop the final line here so these are explicitly interval-derived diagnostics,
    # not true per-record latency percentiles.
    for line in matched_lines[:-1]:
        parsed = parse_summary_line(line)
        parsed["producer_index"] = producer_index
        parsed["producer_count"] = producer_count
        interval_summaries.append(parsed)

records_sent = sum(item["records_sent"] or 0 for item in per_producer)
throughput_records_per_sec = sum(item["throughput_records_per_sec"] or 0 for item in per_producer)
throughput_mb_per_sec = sum(item["throughput_mb_per_sec"] or 0 for item in per_producer)
latency_weight = sum(item["records_sent"] or 0 for item in per_producer if item["avg_latency_ms"] is not None)
avg_latency_ms = None
if latency_weight:
    avg_latency_ms = sum((item["avg_latency_ms"] or 0) * (item["records_sent"] or 0) for item in per_producer) / latency_weight
max_values = [item["max_latency_ms"] for item in per_producer if item["max_latency_ms"] is not None]
producer_throughputs = [item["throughput_records_per_sec"] for item in per_producer if item["throughput_records_per_sec"] is not None]
producer_avg_latencies = [item["avg_latency_ms"] for item in per_producer if item["avg_latency_ms"] is not None]
interval_avg_latencies = [item["avg_latency_ms"] for item in interval_summaries if item["avg_latency_ms"] is not None]
interval_max_latencies = [item["max_latency_ms"] for item in interval_summaries if item["max_latency_ms"] is not None]
print(json.dumps({
    "records_sent": records_sent,
    "throughput_records_per_sec": throughput_records_per_sec,
    "throughput_mb_per_sec": throughput_mb_per_sec,
    "avg_latency_ms": avg_latency_ms,
    "max_latency_ms": max(max_values) if max_values else None,
    "producer_count_observed": len(per_producer),
    "producer_throughput_records_per_sec_min": min(producer_throughputs) if producer_throughputs else None,
    "producer_throughput_records_per_sec_max": max(producer_throughputs) if producer_throughputs else None,
    "producer_avg_latency_ms_min": min(producer_avg_latencies) if producer_avg_latencies else None,
    "producer_avg_latency_ms_max": max(producer_avg_latencies) if producer_avg_latencies else None,
    "interval_summary_count": len(interval_summaries),
    "interval_avg_latency_ms_p95": percentile(interval_avg_latencies, 95),
    "interval_avg_latency_ms_p99": percentile(interval_avg_latencies, 99),
    "interval_max_latency_ms_p95": percentile(interval_max_latencies, 95),
    "interval_max_latency_ms_p99": percentile(interval_max_latencies, 99),
    "producer_summaries": per_producer,
    "interval_summaries": interval_summaries,
}))
PY
)"

PARSED_TELEMETRY="$(
  TELEMETRY_DIR="${TELEMETRY_DIR}" python3 - <<'PY'
import glob
import json
import os

telemetry_dir = os.environ["TELEMETRY_DIR"]

def mean(values):
    return sum(values) / len(values) if values else None

def summarise_file(path):
    samples = []
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                samples.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    if not samples:
        return None

    def values(key):
        return [sample[key] for sample in samples if isinstance(sample.get(key), (int, float))]

    first = samples[0]
    last = samples[-1]
    cpu_values = values("cpu_percent")
    memory_values = values("memory_used_percent")

    return {
        "role": first.get("role"),
        "host_id": first.get("host_id"),
        "sample_count": len(samples),
        "started_at": first.get("timestamp"),
        "ended_at": last.get("timestamp"),
        "cpu_percent_mean": mean(cpu_values),
        "cpu_percent_max": max(cpu_values) if cpu_values else None,
        "memory_used_percent_mean": mean(memory_values),
        "memory_used_percent_max": max(memory_values) if memory_values else None,
        "network_rx_bytes_delta": (last.get("network_rx_bytes") - first.get("network_rx_bytes")) if isinstance(last.get("network_rx_bytes"), int) and isinstance(first.get("network_rx_bytes"), int) else None,
        "network_tx_bytes_delta": (last.get("network_tx_bytes") - first.get("network_tx_bytes")) if isinstance(last.get("network_tx_bytes"), int) and isinstance(first.get("network_tx_bytes"), int) else None,
        "disk_read_sectors_delta": (last.get("disk_read_sectors") - first.get("disk_read_sectors")) if isinstance(last.get("disk_read_sectors"), int) and isinstance(first.get("disk_read_sectors"), int) else None,
        "disk_write_sectors_delta": (last.get("disk_write_sectors") - first.get("disk_write_sectors")) if isinstance(last.get("disk_write_sectors"), int) and isinstance(first.get("disk_write_sectors"), int) else None,
        "source_file": os.path.basename(path),
    }

hosts = []
if os.path.isdir(telemetry_dir):
    for path in sorted(glob.glob(os.path.join(telemetry_dir, "*.jsonl"))):
        summary = summarise_file(path)
        if summary:
            hosts.append(summary)

broker_cpu = [host["cpu_percent_mean"] for host in hosts if host.get("role") == "broker" and host.get("cpu_percent_mean") is not None]
client_cpu = [host["cpu_percent_mean"] for host in hosts if host.get("role") == "benchmark_client" and host.get("cpu_percent_mean") is not None]
broker_memory = [host["memory_used_percent_mean"] for host in hosts if host.get("role") == "broker" and host.get("memory_used_percent_mean") is not None]
client_memory = [host["memory_used_percent_mean"] for host in hosts if host.get("role") == "benchmark_client" and host.get("memory_used_percent_mean") is not None]
broker_rx = [host["network_rx_bytes_delta"] for host in hosts if host.get("role") == "broker" and host.get("network_rx_bytes_delta") is not None]
broker_tx = [host["network_tx_bytes_delta"] for host in hosts if host.get("role") == "broker" and host.get("network_tx_bytes_delta") is not None]
client_rx = [host["network_rx_bytes_delta"] for host in hosts if host.get("role") == "benchmark_client" and host.get("network_rx_bytes_delta") is not None]
client_tx = [host["network_tx_bytes_delta"] for host in hosts if host.get("role") == "benchmark_client" and host.get("network_tx_bytes_delta") is not None]
broker_disk_read = [host["disk_read_sectors_delta"] for host in hosts if host.get("role") == "broker" and host.get("disk_read_sectors_delta") is not None]
broker_disk_write = [host["disk_write_sectors_delta"] for host in hosts if host.get("role") == "broker" and host.get("disk_write_sectors_delta") is not None]
client_disk_read = [host["disk_read_sectors_delta"] for host in hosts if host.get("role") == "benchmark_client" and host.get("disk_read_sectors_delta") is not None]
client_disk_write = [host["disk_write_sectors_delta"] for host in hosts if host.get("role") == "benchmark_client" and host.get("disk_write_sectors_delta") is not None]

print(json.dumps({
    "enabled": bool(hosts),
    "sample_interval_seconds": None,
    "host_count": len(hosts),
    "hosts": hosts,
    "broker_cpu_percent_mean": mean(broker_cpu),
    "broker_cpu_percent_max_mean": mean([host["cpu_percent_max"] for host in hosts if host.get("role") == "broker" and host.get("cpu_percent_max") is not None]),
    "benchmark_client_cpu_percent_mean": mean(client_cpu),
    "broker_memory_used_percent_mean": mean(broker_memory),
    "benchmark_client_memory_used_percent_mean": mean(client_memory),
    "broker_network_rx_bytes_delta_mean": mean(broker_rx),
    "broker_network_tx_bytes_delta_mean": mean(broker_tx),
    "broker_network_rx_bytes_delta_total": sum(broker_rx) if broker_rx else None,
    "broker_network_tx_bytes_delta_total": sum(broker_tx) if broker_tx else None,
    "benchmark_client_network_rx_bytes_delta": client_rx[0] if client_rx else None,
    "benchmark_client_network_tx_bytes_delta": client_tx[0] if client_tx else None,
    "broker_disk_read_sectors_delta_mean": mean(broker_disk_read),
    "broker_disk_write_sectors_delta_mean": mean(broker_disk_write),
    "broker_disk_read_sectors_delta_total": sum(broker_disk_read) if broker_disk_read else None,
    "broker_disk_write_sectors_delta_total": sum(broker_disk_write) if broker_disk_write else None,
    "benchmark_client_disk_read_sectors_delta": client_disk_read[0] if client_disk_read else None,
    "benchmark_client_disk_write_sectors_delta": client_disk_write[0] if client_disk_write else None,
    "source_directory": "host-telemetry" if hosts else None,
}))
PY
)"

TEMP_RESULT="$(mktemp "${RUN_DIR}/result.XXXXXX.json")"
jq \
  --arg summary_lines "${SUMMARY_LINES}" \
  --argjson parsed_metrics "${PARSED_METRICS}" \
  --argjson parsed_telemetry "${PARSED_TELEMETRY}" \
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
      producer_count_observed: $parsed_metrics.producer_count_observed,
      producer_throughput_records_per_sec_min: $parsed_metrics.producer_throughput_records_per_sec_min,
      producer_throughput_records_per_sec_max: $parsed_metrics.producer_throughput_records_per_sec_max,
      producer_avg_latency_ms_min: $parsed_metrics.producer_avg_latency_ms_min,
      producer_avg_latency_ms_max: $parsed_metrics.producer_avg_latency_ms_max,
      interval_summary_count: $parsed_metrics.interval_summary_count,
      interval_avg_latency_ms_p95: $parsed_metrics.interval_avg_latency_ms_p95,
      interval_avg_latency_ms_p99: $parsed_metrics.interval_avg_latency_ms_p99,
      interval_max_latency_ms_p95: $parsed_metrics.interval_max_latency_ms_p95,
      interval_max_latency_ms_p99: $parsed_metrics.interval_max_latency_ms_p99,
      producer_summaries: $parsed_metrics.producer_summaries,
      interval_summaries: $parsed_metrics.interval_summaries
    },
    host_telemetry: $parsed_telemetry,
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
