#!/usr/bin/env bash

set -Eeuo pipefail

TOPIC="${TOPIC:-benchmark-topic}"
BOOTSTRAP_SERVERS="${BOOTSTRAP_SERVERS:-}"
NUM_RECORDS="${NUM_RECORDS:-100000}"
RECORD_SIZE="${RECORD_SIZE:-1024}"
THROUGHPUT="${THROUGHPUT:--1}"
PARTITIONS="${PARTITIONS:-6}"
REPLICATION_FACTOR="${REPLICATION_FACTOR:-3}"
MIN_INSYNC_REPLICAS="${MIN_INSYNC_REPLICAS:-2}"
BROKER_COUNT="${BROKER_COUNT:-3}"
BASELINE_NAME="${BASELINE_NAME:-plaintext-default}"
SWEEP_NAME="${SWEEP_NAME:-ad-hoc-sweep}"
SWEEP_VARIABLE="${SWEEP_VARIABLE:-none}"
SWEEP_VALUE="${SWEEP_VALUE:-none}"
TRIAL_INDEX="${TRIAL_INDEX:-1}"
TRIAL_COUNT="${TRIAL_COUNT:-1}"
SECURITY_MODE="${SECURITY_MODE:-plaintext}"
PRODUCER_COUNT="${PRODUCER_COUNT:-1}"
CONSUMER_COUNT="${CONSUMER_COUNT:-1}"
BATCH_SIZE="${BATCH_SIZE:-16384}"
LINGER_MS="${LINGER_MS:-5}"
ACKS="${ACKS:-all}"
COMPRESSION_TYPE="${COMPRESSION_TYPE:-none}"
RESULT_ROOT="${RESULT_ROOT:-/var/lib/kafka-client/results}"
RUN_ID="${RUN_ID:-$(date -u +"%Y%m%dT%H%M%SZ")-plaintext-producer}"
DELETE_TOPIC_AFTER_RUN="${DELETE_TOPIC_AFTER_RUN:-true}"
KAFKA_VERSION="${KAFKA_VERSION:-3.8.0}"
SCALA_VERSION="${SCALA_VERSION:-2.13}"
INSTALL_DIR="${INSTALL_DIR:-/opt}"
KAFKA_HOME="${INSTALL_DIR}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
CLIENT_CONFIG="${CLIENT_CONFIG:-/etc/kafka/client/plaintext-client.properties}"
RUN_DIR="${RESULT_ROOT}/${RUN_ID}"
RAW_OUTPUT="${RUN_DIR}/producer-perf.log"
METADATA_JSON="${RUN_DIR}/metadata.json"
TOPIC_OUTPUT="${RUN_DIR}/topic-create.log"
TOPIC_DELETE_OUTPUT="${RUN_DIR}/topic-delete.log"
TEMP_METADATA=""
RUN_TOPIC="${TOPIC}-${RUN_ID}"
PRODUCER_EXIT_CODE=0
PRODUCER_PIDS=()
PRODUCER_LOGS=()

cleanup() {
  if [[ -n "${TEMP_METADATA}" && -f "${TEMP_METADATA}" ]]; then
    rm -f "${TEMP_METADATA}"
  fi
}

trap cleanup EXIT

if [[ -z "${BOOTSTRAP_SERVERS}" ]]; then
  echo "Set BOOTSTRAP_SERVERS."
  exit 1
fi

mkdir -p "${RUN_DIR}"

"${KAFKA_HOME}/bin/kafka-topics.sh" \
  --bootstrap-server "${BOOTSTRAP_SERVERS}" \
  --command-config "${CLIENT_CONFIG}" \
  --create \
  --if-not-exists \
  --topic "${RUN_TOPIC}" \
  --partitions "${PARTITIONS}" \
  --replication-factor "${REPLICATION_FACTOR}" \
  --config "min.insync.replicas=${MIN_INSYNC_REPLICAS}" \
  > "${TOPIC_OUTPUT}" 2>&1

set +e
for ((producer_index = 1; producer_index <= PRODUCER_COUNT; producer_index++)); do
  producer_records=$((NUM_RECORDS / PRODUCER_COUNT))
  if (( producer_index <= NUM_RECORDS % PRODUCER_COUNT )); then
    producer_records=$((producer_records + 1))
  fi

  if [[ "${THROUGHPUT}" == "-1" ]]; then
    producer_throughput="-1"
  else
    producer_throughput=$((THROUGHPUT / PRODUCER_COUNT))
    if (( producer_index <= THROUGHPUT % PRODUCER_COUNT )); then
      producer_throughput=$((producer_throughput + 1))
    fi
    if (( producer_throughput < 1 )); then
      producer_throughput=1
    fi
  fi

  producer_log="${RUN_DIR}/producer-perf-${producer_index}.log"
  PRODUCER_LOGS+=("${producer_log}")
  {
    echo "producer_index=${producer_index}"
    echo "producer_count=${PRODUCER_COUNT}"
    echo "producer_records=${producer_records}"
    echo "producer_throughput=${producer_throughput}"
    "${KAFKA_HOME}/bin/kafka-producer-perf-test.sh" \
      --topic "${RUN_TOPIC}" \
      --num-records "${producer_records}" \
      --record-size "${RECORD_SIZE}" \
      --throughput "${producer_throughput}" \
      --producer.config "${CLIENT_CONFIG}" \
      --producer-props \
      "bootstrap.servers=${BOOTSTRAP_SERVERS}" \
      "batch.size=${BATCH_SIZE}" \
      "linger.ms=${LINGER_MS}" \
      "acks=${ACKS}" \
      "compression.type=${COMPRESSION_TYPE}"
  } > "${producer_log}" 2>&1 &
  PRODUCER_PIDS+=("$!")
done

for producer_pid in "${PRODUCER_PIDS[@]}"; do
  if ! wait "${producer_pid}"; then
    PRODUCER_EXIT_CODE=1
  fi
done

{
  echo "run_id=${RUN_ID}"
  echo "producer_count=${PRODUCER_COUNT}"
  for producer_log in "${PRODUCER_LOGS[@]}"; do
    echo "----- ${producer_log} -----"
    cat "${producer_log}"
  done
} > "${RAW_OUTPUT}"
set -e

if [[ "${DELETE_TOPIC_AFTER_RUN}" == "true" ]]; then
  "${KAFKA_HOME}/bin/kafka-topics.sh" \
    --bootstrap-server "${BOOTSTRAP_SERVERS}" \
    --command-config "${CLIENT_CONFIG}" \
    --delete \
    --if-exists \
    --topic "${RUN_TOPIC}" \
    > "${TOPIC_DELETE_OUTPUT}" 2>&1 || true
fi

TEMP_METADATA="$(mktemp "${RUN_DIR}/metadata.XXXXXX.json")"
cat > "${TEMP_METADATA}" <<EOF
{
  "run_id": "${RUN_ID}",
  "security_mode": "${SECURITY_MODE}",
  "baseline_name": "${BASELINE_NAME}",
  "sweep_name": "${SWEEP_NAME}",
  "sweep_variable": "${SWEEP_VARIABLE}",
  "sweep_value": "${SWEEP_VALUE}",
  "trial_index": ${TRIAL_INDEX},
  "trial_count": ${TRIAL_COUNT},
  "topic": "${RUN_TOPIC}",
  "base_topic": "${TOPIC}",
  "delete_topic_after_run": ${DELETE_TOPIC_AFTER_RUN},
  "bootstrap_servers": "${BOOTSTRAP_SERVERS}",
  "broker_count": ${BROKER_COUNT},
  "num_records": ${NUM_RECORDS},
  "record_size": ${RECORD_SIZE},
  "throughput_limit": ${THROUGHPUT},
  "partitions": ${PARTITIONS},
  "replication_factor": ${REPLICATION_FACTOR},
  "min_insync_replicas": ${MIN_INSYNC_REPLICAS},
  "producer_count": ${PRODUCER_COUNT},
  "consumer_count": ${CONSUMER_COUNT},
  "batch_size": ${BATCH_SIZE},
  "linger_ms": ${LINGER_MS},
  "acks": "${ACKS}",
  "compression_type": "${COMPRESSION_TYPE}",
  "producer_logs": [
$(printf '    "%s"' "${PRODUCER_LOGS[0]}")
$(for ((log_index = 1; log_index < ${#PRODUCER_LOGS[@]}; log_index++)); do printf ',\n    "%s"' "${PRODUCER_LOGS[$log_index]}"; done)
  ],
  "raw_output": "${RAW_OUTPUT}"
}
EOF
mv "${TEMP_METADATA}" "${METADATA_JSON}"
TEMP_METADATA=""
chmod -R a+rX "${RUN_DIR}"

if [[ "${PRODUCER_EXIT_CODE}" -ne 0 ]]; then
  echo "Producer benchmark failed with exit code ${PRODUCER_EXIT_CODE}. See ${RAW_OUTPUT}"
  exit "${PRODUCER_EXIT_CODE}"
fi

echo "Producer benchmark run completed at ${RUN_DIR}"
