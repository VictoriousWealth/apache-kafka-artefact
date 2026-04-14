#!/usr/bin/env bash

set -Eeuo pipefail

KAFKA_VERSION="${KAFKA_VERSION:-3.8.0}"
SCALA_VERSION="${SCALA_VERSION:-2.13}"
INSTALL_DIR="${INSTALL_DIR:-/opt}"
KAFKA_TGZ="kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
KAFKA_HOME="${INSTALL_DIR}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
KAFKA_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${KAFKA_TGZ}"
TEMP_TGZ=""

cleanup() {
  if [[ -n "${TEMP_TGZ}" && -f "${TEMP_TGZ}" ]]; then
    rm -f "${TEMP_TGZ}"
  fi
}

trap cleanup EXIT

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

apt-get update
apt-get install -y openjdk-17-jre-headless wget tar jq

cd "${INSTALL_DIR}"

if [[ ! -x "${KAFKA_HOME}/bin/kafka-topics.sh" ]]; then
  TEMP_TGZ="$(mktemp "${INSTALL_DIR}/kafka-client-download.XXXXXX.tgz")"
  wget -q -O "${TEMP_TGZ}" "${KAFKA_URL}"
  tar -xzf "${TEMP_TGZ}"
fi

mkdir -p /etc/kafka/client
mkdir -p /var/lib/kafka-client/results

echo "Kafka client tooling installed at ${KAFKA_HOME}"
