#!/usr/bin/env bash

set -Eeuo pipefail

KAFKA_VERSION="${KAFKA_VERSION:-3.8.0}"
SCALA_VERSION="${SCALA_VERSION:-2.13}"
INSTALL_DIR="${INSTALL_DIR:-/opt}"
KAFKA_HOME="${INSTALL_DIR}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
OUTPUT_FILE="${OUTPUT_FILE:-/etc/kafka/cluster.id}"
TEMP_OUTPUT=""

cleanup() {
  if [[ -n "${TEMP_OUTPUT}" && -f "${TEMP_OUTPUT}" ]]; then
    rm -f "${TEMP_OUTPUT}"
  fi
}

trap cleanup EXIT

if [[ ! -x "${KAFKA_HOME}/bin/kafka-storage.sh" ]]; then
  echo "Kafka is not installed at ${KAFKA_HOME}"
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"

if [[ -s "${OUTPUT_FILE}" ]]; then
  echo "Cluster ID already present at ${OUTPUT_FILE}"
  exit 0
fi

TEMP_OUTPUT="$(mktemp "$(dirname "${OUTPUT_FILE}")/cluster.id.XXXXXX")"
"${KAFKA_HOME}/bin/kafka-storage.sh" random-uuid > "${TEMP_OUTPUT}"
mv "${TEMP_OUTPUT}" "${OUTPUT_FILE}"
TEMP_OUTPUT=""

echo "Cluster ID written to ${OUTPUT_FILE}"
