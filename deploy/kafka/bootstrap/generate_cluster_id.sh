#!/usr/bin/env bash

set -euo pipefail

KAFKA_VERSION="${KAFKA_VERSION:-3.8.0}"
SCALA_VERSION="${SCALA_VERSION:-2.13}"
INSTALL_DIR="${INSTALL_DIR:-/opt}"
KAFKA_HOME="${INSTALL_DIR}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
OUTPUT_FILE="${OUTPUT_FILE:-/etc/kafka/cluster.id}"

if [[ ! -x "${KAFKA_HOME}/bin/kafka-storage.sh" ]]; then
  echo "Kafka is not installed at ${KAFKA_HOME}"
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"
"${KAFKA_HOME}/bin/kafka-storage.sh" random-uuid > "${OUTPUT_FILE}"

echo "Cluster ID written to ${OUTPUT_FILE}"
