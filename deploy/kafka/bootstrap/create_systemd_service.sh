#!/usr/bin/env bash

set -Eeuo pipefail

KAFKA_VERSION="${KAFKA_VERSION:-3.8.0}"
SCALA_VERSION="${SCALA_VERSION:-2.13}"
INSTALL_DIR="${INSTALL_DIR:-/opt}"
KAFKA_HOME="${INSTALL_DIR}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
SERVICE_PATH="/etc/systemd/system/kafka.service"
TEMP_SERVICE=""

cleanup() {
  if [[ -n "${TEMP_SERVICE}" && -f "${TEMP_SERVICE}" ]]; then
    rm -f "${TEMP_SERVICE}"
  fi
}

trap cleanup EXIT

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

TEMP_SERVICE="$(mktemp "$(dirname "${SERVICE_PATH}")/kafka.service.XXXXXX")"

cat > "${TEMP_SERVICE}" <<EOF
[Unit]
Description=Apache Kafka
After=network.target

[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=${KAFKA_HOME}/bin/kafka-server-start.sh /etc/kafka/server.properties
ExecStop=${KAFKA_HOME}/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=5
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

if [[ ! -f "${SERVICE_PATH}" ]] || ! cmp -s "${TEMP_SERVICE}" "${SERVICE_PATH}"; then
  mv "${TEMP_SERVICE}" "${SERVICE_PATH}"
  TEMP_SERVICE=""
else
  rm -f "${TEMP_SERVICE}"
  TEMP_SERVICE=""
fi

systemctl daemon-reload
systemctl enable kafka

echo "Systemd service created at ${SERVICE_PATH}"
