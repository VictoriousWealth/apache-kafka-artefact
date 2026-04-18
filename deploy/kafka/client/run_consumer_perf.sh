#!/usr/bin/env bash

set -Eeuo pipefail

TOPIC="${TOPIC:-consumer-benchmark-topic}"
BOOTSTRAP_SERVERS="${BOOTSTRAP_SERVERS:-}"
NUM_RECORDS="${NUM_RECORDS:-100000}"
RECORD_SIZE="${RECORD_SIZE:-1024}"
PRODUCER_THROUGHPUT="${PRODUCER_THROUGHPUT:--1}"
PARTITIONS="${PARTITIONS:-6}"
REPLICATION_FACTOR="${REPLICATION_FACTOR:-3}"
MIN_INSYNC_REPLICAS="${MIN_INSYNC_REPLICAS:-2}"
BROKER_COUNT="${BROKER_COUNT:-3}"
BASELINE_NAME="${BASELINE_NAME:-consumer-default}"
SWEEP_NAME="${SWEEP_NAME:-consumer-slice}"
SWEEP_VARIABLE="${SWEEP_VARIABLE:-none}"
SWEEP_VALUE="${SWEEP_VALUE:-none}"
TRIAL_INDEX="${TRIAL_INDEX:-1}"
TRIAL_COUNT="${TRIAL_COUNT:-1}"
SECURITY_MODE="${SECURITY_MODE:-plaintext}"
CONSUMER_COUNT="${CONSUMER_COUNT:-1}"
BATCH_SIZE="${BATCH_SIZE:-16384}"
LINGER_MS="${LINGER_MS:-5}"
ACKS="${ACKS:-all}"
COMPRESSION_TYPE="${COMPRESSION_TYPE:-none}"
RESULT_ROOT="${RESULT_ROOT:-/var/lib/kafka-client/results}"
RUN_ID="${RUN_ID:-$(date -u +"%Y%m%dT%H%M%SZ")-${SECURITY_MODE}-consumer}"
DELETE_TOPIC_AFTER_RUN="${DELETE_TOPIC_AFTER_RUN:-true}"
KAFKA_VERSION="${KAFKA_VERSION:-3.8.0}"
SCALA_VERSION="${SCALA_VERSION:-2.13}"
INSTALL_DIR="${INSTALL_DIR:-/opt}"
KAFKA_HOME="${INSTALL_DIR}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
CLIENT_CONFIG="${CLIENT_CONFIG:-/etc/kafka/client/plaintext-client.properties}"
RUN_DIR="${RESULT_ROOT}/${RUN_ID}"
RAW_OUTPUT="${RUN_DIR}/consumer-perf.log"
PRODUCER_OUTPUT="${RUN_DIR}/producer-seed.log"
METADATA_JSON="${RUN_DIR}/metadata.json"
TOPIC_OUTPUT="${RUN_DIR}/topic-create.log"
TOPIC_DELETE_OUTPUT="${RUN_DIR}/topic-delete.log"
TEMP_METADATA=""
RUN_TOPIC="${TOPIC}-${RUN_ID}"

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

"${KAFKA_HOME}/bin/kafka-producer-perf-test.sh" \
  --topic "${RUN_TOPIC}" \
  --num-records "${NUM_RECORDS}" \
  --record-size "${RECORD_SIZE}" \
  --throughput "${PRODUCER_THROUGHPUT}" \
  --producer.config "${CLIENT_CONFIG}" \
  --producer-props \
  "bootstrap.servers=${BOOTSTRAP_SERVERS}" \
  "batch.size=${BATCH_SIZE}" \
  "linger.ms=${LINGER_MS}" \
  "acks=${ACKS}" \
  "compression.type=${COMPRESSION_TYPE}" \
  > "${PRODUCER_OUTPUT}" 2>&1

"${KAFKA_HOME}/bin/kafka-consumer-perf-test.sh" \
  --bootstrap-server "${BOOTSTRAP_SERVERS}" \
  --consumer.config "${CLIENT_CONFIG}" \
  --topic "${RUN_TOPIC}" \
  --messages "${NUM_RECORDS}" \
  --threads "${CONSUMER_COUNT}" \
  --show-detailed-stats \
  > "${RAW_OUTPUT}" 2>&1

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
  "benchmark_type": "consumer",
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
  "producer_throughput_limit": ${PRODUCER_THROUGHPUT},
  "partitions": ${PARTITIONS},
  "replication_factor": ${REPLICATION_FACTOR},
  "min_insync_replicas": ${MIN_INSYNC_REPLICAS},
  "producer_count": 1,
  "consumer_count": ${CONSUMER_COUNT},
  "batch_size": ${BATCH_SIZE},
  "linger_ms": ${LINGER_MS},
  "acks": "${ACKS}",
  "compression_type": "${COMPRESSION_TYPE}",
  "raw_output": "${RAW_OUTPUT}",
  "producer_seed_output": "${PRODUCER_OUTPUT}"
}
EOF
mv "${TEMP_METADATA}" "${METADATA_JSON}"
TEMP_METADATA=""
chmod -R a+rX "${RUN_DIR}"

echo "Consumer benchmark run completed at ${RUN_DIR}"
