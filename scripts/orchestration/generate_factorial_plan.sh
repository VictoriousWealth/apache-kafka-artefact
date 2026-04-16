#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <factorial-config.json> [output-jsonl]"
  exit 1
fi

CONFIG_FILE="$1"
OUTPUT_FILE="${2:-}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "Factorial config not found: ${CONFIG_FILE}"
  exit 1
fi

generate_plan() {
  jq -c '
    . as $cfg |
    $cfg.parameters.broker_count[] as $broker_count |
    $cfg.parameters.replication_factor[] as $replication_factor |
    $cfg.parameters.min_insync_replicas[] as $min_insync_replicas |
    select($replication_factor <= $broker_count) |
    select($min_insync_replicas <= $replication_factor) |
    $cfg.parameters.message_size_bytes[] as $message_size_bytes |
    $cfg.parameters.target_messages_per_second[] as $target_messages_per_second |
    $cfg.parameters.batch_size[] as $batch_size |
    $cfg.parameters.acks[] as $acks |
    $cfg.parameters.producer_count[] as $producer_count |
    $cfg.parameters.compression_type[] as $compression_type |
    range(1; (($cfg.trials // 1) + 1)) as $trial_index |
    {
      factorial_name: $cfg.name,
      security_mode: $cfg.security_mode,
      trial_index: $trial_index,
      trial_count: ($cfg.trials // 1),
      topic: $cfg.fixed.topic,
      broker_count: $broker_count,
      partition_count: $cfg.fixed.partition_count,
      replication_factor: $replication_factor,
      min_insync_replicas: $min_insync_replicas,
      message_size_bytes: $message_size_bytes,
      num_records: $cfg.fixed.num_records,
      target_messages_per_second: $target_messages_per_second,
      producer_count: $producer_count,
      consumer_count: $cfg.fixed.consumer_count,
      batch_size: $batch_size,
      linger_ms: $cfg.fixed.linger_ms,
      acks: $acks,
      compression_type: $compression_type
    }
  ' "${CONFIG_FILE}"
}

if [[ -n "${OUTPUT_FILE}" ]]; then
  mkdir -p "$(dirname "${OUTPUT_FILE}")"
  TEMP_FILE="$(mktemp "$(dirname "${OUTPUT_FILE}")/factorial-plan.XXXXXX.jsonl")"
  generate_plan > "${TEMP_FILE}"
  mv "${TEMP_FILE}" "${OUTPUT_FILE}"
  echo "Wrote $(wc -l < "${OUTPUT_FILE}" | tr -d ' ') planned runs to ${OUTPUT_FILE}"
else
  generate_plan
fi
