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

COMPLETED_COUNT=0
STARTED_COUNT=0
FAILURE_COUNT=0
if [[ -f "${SWEEP_DIR}/completed.jsonl" ]]; then
  COMPLETED_COUNT="$(wc -l < "${SWEEP_DIR}/completed.jsonl" | tr -d ' ')"
fi
if [[ -f "${SWEEP_DIR}/started.jsonl" ]]; then
  STARTED_COUNT="$(wc -l < "${SWEEP_DIR}/started.jsonl" | tr -d ' ')"
fi
if [[ -f "${SWEEP_DIR}/failures.jsonl" ]]; then
  FAILURE_COUNT="$(wc -l < "${SWEEP_DIR}/failures.jsonl" | tr -d ' ')"
fi

TEMP_JSON="$(mktemp "${SWEEP_DIR}/summary.XXXXXX.json")"
TEMP_CSV="$(mktemp "${SWEEP_DIR}/summary.XXXXXX.csv")"

jq -s \
  --argjson completed_count "${COMPLETED_COUNT}" \
  --argjson started_count "${STARTED_COUNT}" \
  --argjson failure_count "${FAILURE_COUNT}" \
  '
  {
    schema_version: "1.0",
    sweep_name: .[0].sweep_name,
    baseline_name: .[0].baseline_name,
    sweep_variable: .[0].sweep_variable,
    run_count: length,
    started_count: $started_count,
    completed_count: $completed_count,
    failure_count: $failure_count,
    trial_count: ([.[].trial_count] | max),
    security_modes: ([.[].security_mode] | unique),
    values_tested: ([.[].sweep_value] | unique),
    grouped_stats: (
      group_by(.sweep_value) |
      map({
        sweep_value: .[0].sweep_value,
        run_count: length,
        trial_indices: ([.[].trial_index] | sort),
        throughput_records_per_sec: {
          mean: ((map(.metrics.throughput_records_per_sec // empty) | add) / (map(.metrics.throughput_records_per_sec // empty) | length)),
          min: (map(.metrics.throughput_records_per_sec // empty) | min),
          max: (map(.metrics.throughput_records_per_sec // empty) | max)
        },
        throughput_mb_per_sec: {
          mean: ((map(.metrics.throughput_mb_per_sec // empty) | add) / (map(.metrics.throughput_mb_per_sec // empty) | length)),
          min: (map(.metrics.throughput_mb_per_sec // empty) | min),
          max: (map(.metrics.throughput_mb_per_sec // empty) | max)
        },
        avg_latency_ms: {
          mean: (
            (map(select(.metrics.avg_latency_ms != null) | .metrics.avg_latency_ms) ) as $vals |
            if ($vals | length) > 0 then (($vals | add) / ($vals | length)) else null end
          ),
          min: (
            (map(select(.metrics.avg_latency_ms != null) | .metrics.avg_latency_ms) ) as $vals |
            if ($vals | length) > 0 then ($vals | min) else null end
          ),
          max: (
            (map(select(.metrics.avg_latency_ms != null) | .metrics.avg_latency_ms) ) as $vals |
            if ($vals | length) > 0 then ($vals | max) else null end
          )
        },
        max_latency_ms: {
          mean: (
            (map(select(.metrics.max_latency_ms != null) | .metrics.max_latency_ms) ) as $vals |
            if ($vals | length) > 0 then (($vals | add) / ($vals | length)) else null end
          ),
          min: (
            (map(select(.metrics.max_latency_ms != null) | .metrics.max_latency_ms) ) as $vals |
            if ($vals | length) > 0 then ($vals | min) else null end
          ),
          max: (
            (map(select(.metrics.max_latency_ms != null) | .metrics.max_latency_ms) ) as $vals |
            if ($vals | length) > 0 then ($vals | max) else null end
          )
        }
      })
    ),
    runs: [
      .[] | {
        run_id,
        security_mode,
        baseline_name,
        sweep_name,
        sweep_variable,
        sweep_value,
        trial_index,
        trial_count,
        broker_count: .cluster.broker_count,
        partitions: .cluster.partitions,
        replication_factor: .cluster.replication_factor,
        min_insync_replicas: .cluster.min_insync_replicas,
        num_records: .run_config.num_records,
        record_size_bytes: .run_config.record_size_bytes,
        throughput_limit_records_per_sec: .run_config.throughput_limit_records_per_sec,
        producer_count: .run_config.producer_count,
        consumer_count: .run_config.consumer_count,
        batch_size: .run_config.batch_size,
        linger_ms: .run_config.linger_ms,
        acks: .run_config.acks,
        compression_type: .run_config.compression_type,
        records_sent: .metrics.records_sent,
        throughput_records_per_sec: .metrics.throughput_records_per_sec,
        throughput_mb_per_sec: .metrics.throughput_mb_per_sec,
        avg_latency_ms: .metrics.avg_latency_ms,
        max_latency_ms: .metrics.max_latency_ms,
        producer_count_observed: .metrics.producer_count_observed,
        producer_throughput_records_per_sec_min: .metrics.producer_throughput_records_per_sec_min,
        producer_throughput_records_per_sec_max: .metrics.producer_throughput_records_per_sec_max,
        producer_avg_latency_ms_min: .metrics.producer_avg_latency_ms_min,
        producer_avg_latency_ms_max: .metrics.producer_avg_latency_ms_max,
        interval_summary_count: .metrics.interval_summary_count,
        interval_avg_latency_ms_p95: .metrics.interval_avg_latency_ms_p95,
        interval_avg_latency_ms_p99: .metrics.interval_avg_latency_ms_p99,
        interval_max_latency_ms_p95: .metrics.interval_max_latency_ms_p95,
        interval_max_latency_ms_p99: .metrics.interval_max_latency_ms_p99,
        telemetry_host_count: (.host_telemetry.host_count // 0),
        benchmark_client_cpu_percent_mean: .host_telemetry.benchmark_client_cpu_percent_mean,
        broker_cpu_percent_mean: .host_telemetry.broker_cpu_percent_mean,
        broker_cpu_percent_max_mean: .host_telemetry.broker_cpu_percent_max_mean,
        benchmark_client_memory_used_percent_mean: .host_telemetry.benchmark_client_memory_used_percent_mean,
        broker_memory_used_percent_mean: .host_telemetry.broker_memory_used_percent_mean,
        benchmark_client_network_rx_bytes_delta: .host_telemetry.benchmark_client_network_rx_bytes_delta,
        benchmark_client_network_tx_bytes_delta: .host_telemetry.benchmark_client_network_tx_bytes_delta,
        broker_network_rx_bytes_delta_mean: .host_telemetry.broker_network_rx_bytes_delta_mean,
        broker_network_tx_bytes_delta_mean: .host_telemetry.broker_network_tx_bytes_delta_mean,
        broker_network_rx_bytes_delta_total: .host_telemetry.broker_network_rx_bytes_delta_total,
        broker_network_tx_bytes_delta_total: .host_telemetry.broker_network_tx_bytes_delta_total,
        benchmark_client_disk_read_sectors_delta: .host_telemetry.benchmark_client_disk_read_sectors_delta,
        benchmark_client_disk_write_sectors_delta: .host_telemetry.benchmark_client_disk_write_sectors_delta,
        broker_disk_read_sectors_delta_mean: .host_telemetry.broker_disk_read_sectors_delta_mean,
        broker_disk_write_sectors_delta_mean: .host_telemetry.broker_disk_write_sectors_delta_mean,
        broker_disk_read_sectors_delta_total: .host_telemetry.broker_disk_read_sectors_delta_total,
        broker_disk_write_sectors_delta_total: .host_telemetry.broker_disk_write_sectors_delta_total
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
    "trial_index",
    "trial_count",
    "broker_count",
    "partitions",
    "replication_factor",
    "min_insync_replicas",
    "num_records",
    "record_size_bytes",
    "throughput_limit_records_per_sec",
    "producer_count",
    "consumer_count",
    "batch_size",
    "linger_ms",
    "acks",
    "compression_type",
    "records_sent",
    "throughput_records_per_sec",
    "throughput_mb_per_sec",
    "avg_latency_ms",
    "max_latency_ms",
    "producer_count_observed",
    "producer_throughput_records_per_sec_min",
    "producer_throughput_records_per_sec_max",
    "producer_avg_latency_ms_min",
    "producer_avg_latency_ms_max",
    "interval_summary_count",
    "interval_avg_latency_ms_p95",
    "interval_avg_latency_ms_p99",
    "interval_max_latency_ms_p95",
    "interval_max_latency_ms_p99",
    "telemetry_host_count",
    "benchmark_client_cpu_percent_mean",
    "broker_cpu_percent_mean",
    "broker_cpu_percent_max_mean",
    "benchmark_client_memory_used_percent_mean",
    "broker_memory_used_percent_mean",
    "benchmark_client_network_rx_bytes_delta",
    "benchmark_client_network_tx_bytes_delta",
    "broker_network_rx_bytes_delta_mean",
    "broker_network_tx_bytes_delta_mean",
    "broker_network_rx_bytes_delta_total",
    "broker_network_tx_bytes_delta_total",
    "benchmark_client_disk_read_sectors_delta",
    "benchmark_client_disk_write_sectors_delta",
    "broker_disk_read_sectors_delta_mean",
    "broker_disk_write_sectors_delta_mean",
    "broker_disk_read_sectors_delta_total",
    "broker_disk_write_sectors_delta_total"
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
      (.trial_index | tostring),
      (.trial_count | tostring),
      (.broker_count | tostring),
      (.partitions | tostring),
      (.replication_factor | tostring),
      (.min_insync_replicas | tostring),
      (.num_records | tostring),
      (.record_size_bytes | tostring),
      (.throughput_limit_records_per_sec | tostring),
      (.producer_count | tostring),
      (.consumer_count | tostring),
      (.batch_size | tostring),
      (.linger_ms | tostring),
      .acks,
      .compression_type,
      (.records_sent | tostring),
      (.throughput_records_per_sec | tostring),
      (.throughput_mb_per_sec | tostring),
      (.avg_latency_ms | tostring),
      (.max_latency_ms | tostring),
      (.producer_count_observed | tostring),
      (.producer_throughput_records_per_sec_min | tostring),
      (.producer_throughput_records_per_sec_max | tostring),
      (.producer_avg_latency_ms_min | tostring),
      (.producer_avg_latency_ms_max | tostring),
      (.interval_summary_count | tostring),
      (.interval_avg_latency_ms_p95 | tostring),
      (.interval_avg_latency_ms_p99 | tostring),
      (.interval_max_latency_ms_p95 | tostring),
      (.interval_max_latency_ms_p99 | tostring),
      (.telemetry_host_count | tostring),
      (.benchmark_client_cpu_percent_mean | tostring),
      (.broker_cpu_percent_mean | tostring),
      (.broker_cpu_percent_max_mean | tostring),
      (.benchmark_client_memory_used_percent_mean | tostring),
      (.broker_memory_used_percent_mean | tostring),
      (.benchmark_client_network_rx_bytes_delta | tostring),
      (.benchmark_client_network_tx_bytes_delta | tostring),
      (.broker_network_rx_bytes_delta_mean | tostring),
      (.broker_network_tx_bytes_delta_mean | tostring),
      (.broker_network_rx_bytes_delta_total | tostring),
      (.broker_network_tx_bytes_delta_total | tostring),
      (.benchmark_client_disk_read_sectors_delta | tostring),
      (.benchmark_client_disk_write_sectors_delta | tostring),
      (.broker_disk_read_sectors_delta_mean | tostring),
      (.broker_disk_write_sectors_delta_mean | tostring),
      (.broker_disk_read_sectors_delta_total | tostring),
      (.broker_disk_write_sectors_delta_total | tostring)
    ]
  ) | @csv' "${TEMP_JSON}" > "${TEMP_CSV}"

mv "${TEMP_JSON}" "${SUMMARY_JSON}"
mv "${TEMP_CSV}" "${SUMMARY_CSV}"
TEMP_JSON=""
TEMP_CSV=""

echo "Sweep summary written to ${SUMMARY_JSON} and ${SUMMARY_CSV}"
