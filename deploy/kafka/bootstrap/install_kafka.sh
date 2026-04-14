#!/usr/bin/env bash

set -euo pipefail

KAFKA_VERSION="${KAFKA_VERSION:-3.8.0}"
SCALA_VERSION="${SCALA_VERSION:-2.13}"
INSTALL_DIR="${INSTALL_DIR:-/opt}"
KAFKA_USER="${KAFKA_USER:-kafka}"
KAFKA_GROUP="${KAFKA_GROUP:-kafka}"
KAFKA_HOME="${INSTALL_DIR}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
KAFKA_TGZ="kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
KAFKA_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${KAFKA_TGZ}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

apt-get update
apt-get install -y openjdk-17-jre-headless wget tar

if ! getent group "${KAFKA_GROUP}" >/dev/null; then
  groupadd --system "${KAFKA_GROUP}"
fi

if ! id -u "${KAFKA_USER}" >/dev/null 2>&1; then
  useradd --system --gid "${KAFKA_GROUP}" --home-dir /var/lib/kafka --create-home --shell /usr/sbin/nologin "${KAFKA_USER}"
fi

cd "${INSTALL_DIR}"

if [[ ! -d "${KAFKA_HOME}" ]]; then
  wget -q "${KAFKA_URL}"
  tar -xzf "${KAFKA_TGZ}"
  rm -f "${KAFKA_TGZ}"
fi

mkdir -p /etc/kafka
mkdir -p /var/lib/kafka/data
mkdir -p /var/log/kafka

chown -R "${KAFKA_USER}:${KAFKA_GROUP}" "${KAFKA_HOME}" /etc/kafka /var/lib/kafka /var/log/kafka

echo "Kafka installed at ${KAFKA_HOME}"
