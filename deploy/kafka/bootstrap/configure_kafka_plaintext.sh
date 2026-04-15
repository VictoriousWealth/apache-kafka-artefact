#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <node_id> <controller_quorum_voters> <advertised_listener_host>"
  exit 1
fi

NODE_ID="$1"
CONTROLLER_QUORUM_VOTERS="$2"
ADVERTISED_HOST="$3"

KAFKA_VERSION="${KAFKA_VERSION:-3.8.0}"
SCALA_VERSION="${SCALA_VERSION:-2.13}"
INSTALL_DIR="${INSTALL_DIR:-/opt}"
KAFKA_HOME="${INSTALL_DIR}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
CONFIG_TEMPLATE="${CONFIG_TEMPLATE:-/etc/kafka/server.properties.template}"
CONFIG_OUTPUT="${CONFIG_OUTPUT:-/etc/kafka/server.properties}"
CLUSTER_ID_FILE="${CLUSTER_ID_FILE:-/etc/kafka/cluster.id}"
TEMP_CONFIG=""

cleanup() {
  if [[ -n "${TEMP_CONFIG}" && -f "${TEMP_CONFIG}" ]]; then
    rm -f "${TEMP_CONFIG}"
  fi
}

trap cleanup EXIT

if [[ ! -f "${CONFIG_TEMPLATE}" ]]; then
  echo "Missing config template at ${CONFIG_TEMPLATE}"
  exit 1
fi

if [[ ! -f "${CLUSTER_ID_FILE}" ]]; then
  echo "Missing cluster id file at ${CLUSTER_ID_FILE}"
  exit 1
fi

CLUSTER_ID="$(tr -d '\n' < "${CLUSTER_ID_FILE}")"
TEMP_CONFIG="$(mktemp "$(dirname "${CONFIG_OUTPUT}")/server.properties.XXXXXX")"

sed \
  -e "s|__NODE_ID__|${NODE_ID}|g" \
  -e "s|__CONTROLLER_QUORUM_VOTERS__|${CONTROLLER_QUORUM_VOTERS}|g" \
  -e "s|__ADVERTISED_HOST__|${ADVERTISED_HOST}|g" \
  "${CONFIG_TEMPLATE}" > "${TEMP_CONFIG}"

mv "${TEMP_CONFIG}" "${CONFIG_OUTPUT}"
TEMP_CONFIG=""

"${KAFKA_HOME}/bin/kafka-storage.sh" format -t "${CLUSTER_ID}" -c "${CONFIG_OUTPUT}" --ignore-formatted

echo "Plaintext Kafka configured with node id ${NODE_ID}"
