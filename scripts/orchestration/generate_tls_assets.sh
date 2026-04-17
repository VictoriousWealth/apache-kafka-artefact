#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib.sh"

OUTPUT_DIR="${OUTPUT_DIR:-.orchestration}"
INVENTORY_FILE="${INVENTORY_FILE:-${OUTPUT_DIR}/inventory.env}"
TLS_DIR="${TLS_DIR:-${OUTPUT_DIR}/tls}"
TLS_STORE_PASSWORD="${TLS_STORE_PASSWORD:-}"
TLS_DAYS="${TLS_DAYS:-365}"

require_file "${INVENTORY_FILE}"

# shellcheck disable=SC1090
source "${INVENTORY_FILE}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required to generate TLS assets."
  exit 1
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool is required to generate Kafka truststores."
  exit 1
fi

if [[ -z "${TLS_STORE_PASSWORD}" ]]; then
  TLS_STORE_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
fi

mkdir -p "${TLS_DIR}/brokers" "${TLS_DIR}/client"
chmod 0700 "${TLS_DIR}"

CA_KEY="${TLS_DIR}/ca.key"
CA_CERT="${TLS_DIR}/ca.crt"
TRUSTSTORE="${TLS_DIR}/kafka.truststore.p12"
TLS_ENV="${TLS_DIR}/tls.env"

if [[ ! -f "${CA_KEY}" || ! -f "${CA_CERT}" ]]; then
  openssl req -x509 -newkey rsa:4096 -sha256 -days "${TLS_DAYS}" -nodes \
    -keyout "${CA_KEY}" \
    -out "${CA_CERT}" \
    -subj "/CN=kafka-artefact-ca"
fi

rm -f "${TRUSTSTORE}"
keytool -importcert -noprompt \
  -alias kafka-artefact-ca \
  -file "${CA_CERT}" \
  -keystore "${TRUSTSTORE}" \
  -storetype PKCS12 \
  -storepass "${TLS_STORE_PASSWORD}" >/dev/null

INDEX=1
while true; do
  PUBLIC_VAR="BROKER_${INDEX}_PUBLIC_IP"
  PRIVATE_VAR="BROKER_${INDEX}_PRIVATE_IP"
  PUBLIC_IP="${!PUBLIC_VAR:-}"
  PRIVATE_IP="${!PRIVATE_VAR:-}"

  if [[ -z "${PRIVATE_IP}" ]]; then
    break
  fi

  if [[ -z "${PUBLIC_IP}" ]]; then
    FALLBACK_PUBLIC_VAR="BROKER_${INDEX}_IP"
    PUBLIC_IP="${!FALLBACK_PUBLIC_VAR:-}"
  fi

  BROKER_DIR="${TLS_DIR}/brokers/broker-${INDEX}"
  mkdir -p "${BROKER_DIR}"

  cat > "${BROKER_DIR}/openssl.cnf" <<EOF
[req]
distinguished_name=req_distinguished_name
req_extensions=v3_req
prompt=no

[req_distinguished_name]
CN=broker-${INDEX}

[v3_req]
subjectAltName=@alt_names

[alt_names]
DNS.1=broker-${INDEX}
DNS.2=localhost
IP.1=${PRIVATE_IP}
IP.2=127.0.0.1
EOF

  if [[ -n "${PUBLIC_IP}" ]]; then
    printf 'IP.3=%s\n' "${PUBLIC_IP}" >> "${BROKER_DIR}/openssl.cnf"
  fi

  openssl req -newkey rsa:2048 -nodes \
    -keyout "${BROKER_DIR}/broker.key" \
    -out "${BROKER_DIR}/broker.csr" \
    -config "${BROKER_DIR}/openssl.cnf"

  openssl x509 -req -sha256 -days "${TLS_DAYS}" \
    -in "${BROKER_DIR}/broker.csr" \
    -CA "${CA_CERT}" \
    -CAkey "${CA_KEY}" \
    -CAcreateserial \
    -out "${BROKER_DIR}/broker.crt" \
    -extensions v3_req \
    -extfile "${BROKER_DIR}/openssl.cnf"

  openssl pkcs12 -export \
    -name "broker-${INDEX}" \
    -inkey "${BROKER_DIR}/broker.key" \
    -in "${BROKER_DIR}/broker.crt" \
    -certfile "${CA_CERT}" \
    -out "${BROKER_DIR}/kafka.server.keystore.p12" \
    -passout "pass:${TLS_STORE_PASSWORD}"

  cp "${TRUSTSTORE}" "${BROKER_DIR}/kafka.server.truststore.p12"
  INDEX=$((INDEX + 1))
done

cp "${TRUSTSTORE}" "${TLS_DIR}/client/kafka.client.truststore.p12"

cat > "${TLS_ENV}" <<EOF
TLS_STORE_PASSWORD='${TLS_STORE_PASSWORD}'
TLS_DIR='${TLS_DIR}'
TLS_DAYS='${TLS_DAYS}'
EOF
chmod 0600 "${TLS_ENV}"

log "TLS assets generated under ${TLS_DIR}"
