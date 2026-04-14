# Kafka Deployment

This directory contains the bootstrap scripts and configuration templates used to install and configure Kafka on AWS EC2 instances.

## Current Scope

The first deployment target is a plaintext KRaft-based Kafka cluster used to validate:

- broker installation
- cluster storage formatting
- baseline broker configuration
- client connectivity from the benchmark runner instance

TLS and mTLS support will be layered on top of this baseline after the plaintext path works end to end.

## Bootstrap Scripts

- `bootstrap/install_kafka.sh`
  Installs Java and Kafka, creates the Kafka user, and prepares directories.

- `bootstrap/install_kafka_client.sh`
  Installs Java, Kafka CLI tooling, and result directories on the benchmark client host.

- `bootstrap/generate_cluster_id.sh`
  Generates a Kafka cluster ID for KRaft storage formatting.

- `bootstrap/configure_kafka_plaintext.sh`
  Renders the plaintext broker config and formats storage.

- `bootstrap/create_systemd_service.sh`
  Creates a `systemd` service for Kafka.

## Plaintext Configuration Template

- `config/server.properties.plaintext.template`
- `client/plaintext-client.properties`
- `client/run_plaintext_producer_perf.sh`

This template is designed for a small three-broker KRaft cluster with:

- `PLAINTEXT` broker traffic on `9092`
- `CONTROLLER` traffic on `9093`
- replication settings aligned with a 3-broker baseline

## Expected Bootstrap Order

1. Install Kafka on each broker node.
2. Generate one cluster ID and distribute it consistently.
3. Render `server.properties` per node with the correct node ID and quorum voters.
4. Format storage.
5. Create the `systemd` service and start Kafka.
6. Prepare the benchmark client with Kafka CLI tooling and client properties.
7. Execute the initial plaintext producer performance run.

## Notes

The current scripts are intentionally simple and assume:

- Ubuntu-based EC2 instances
- root or sudo execution during bootstrap
- a separate mechanism will later distribute config files and cluster metadata
