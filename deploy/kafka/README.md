# Kafka Deployment

This directory contains the bootstrap scripts and configuration templates used to install and configure Kafka on AWS EC2 instances.

## Current Scope

Implemented deployment modes:

- `plaintext`: Kafka broker data traffic on `9092`.
- `tls`: server-authenticated TLS broker data traffic on `9094`.

Pending deployment mode:

- `mtls`: mutual TLS with client-certificate authentication.

The KRaft controller listener remains private and plaintext on `9093` in the current TLS implementation. The dissertation security comparison concerns Kafka data-plane client/broker and broker/broker traffic.

## Bootstrap Scripts

- `bootstrap/install_kafka.sh`
  Installs Java and Kafka, creates the Kafka user, and prepares directories.

- `bootstrap/install_kafka_client.sh`
  Installs Java, Kafka CLI tooling, and result directories on the benchmark client host.

- `bootstrap/generate_cluster_id.sh`
  Generates a Kafka cluster ID for KRaft storage formatting.

- `bootstrap/configure_kafka_plaintext.sh`
  Renders the plaintext broker config and formats storage.

- `bootstrap/configure_kafka_tls.sh`
  Renders the TLS broker config, validates TLS stores, and formats storage.

- `bootstrap/create_systemd_service.sh`
  Creates a `systemd` service for Kafka.

## Configuration Templates

Plaintext:

- `config/server.properties.plaintext.template`
- `client/plaintext-client.properties`

TLS:

- `config/server.properties.tls.template`
- `client/tls-client.properties.template`

Benchmark runner:

- `client/run_plaintext_producer_perf.sh`

The benchmark runner name is historical. It now accepts `SECURITY_MODE`, `CLIENT_CONFIG`, and `BOOTSTRAP_SERVERS`, so the same producer benchmark script can execute plaintext or TLS runs.

## TLS Asset Flow

TLS assets are generated locally under `.orchestration/tls` by:

```bash
scripts/orchestration/generate_tls_assets.sh
```

Generated assets include:

- a local CA certificate/key
- one broker PKCS#12 keystore per broker
- broker truststores
- benchmark-client truststore
- `.orchestration/tls/tls.env` containing the generated store password

The `.orchestration` directory is ignored by git, so generated keys and truststores are not committed.

## Expected Bootstrap Order

Plaintext:

1. Install Kafka on each broker node.
2. Generate one cluster ID and distribute it consistently.
3. Render plaintext `server.properties` per node.
4. Format storage.
5. Create the `systemd` service and start Kafka.
6. Prepare the benchmark client with plaintext client properties.

TLS:

1. Generate TLS assets.
2. Install Kafka on each broker node if needed.
3. Copy broker keystores/truststores to `/etc/kafka/tls`.
4. Render TLS `server.properties` per node.
5. Format storage.
6. Create the `systemd` service and restart Kafka.
7. Install TLS client truststore/properties on the benchmark client.
8. Verify Kafka API readiness over `SSL://<private-ip>:9094`.

## Notes

The current scripts assume:

- Ubuntu-based EC2 instances.
- root or sudo execution during bootstrap.
- generated TLS materials are development/test artefacts, not production PKI.
- mTLS will extend the TLS mode by adding client keystores and `ssl.client.auth=required`.
