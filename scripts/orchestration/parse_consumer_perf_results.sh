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
TELEMETRY_DIR="${RUN_DIR}/host-telemetry"
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
  --argjson parsed_metrics "${PARSED_METRICS}" \
  --argjson parsed_telemetry "${PARSED_TELEMETRY}" \
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
    host_telemetry: $parsed_telemetry,
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
