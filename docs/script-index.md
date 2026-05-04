# Script Index

This document is the authoritative index for repository scripts. It covers shell and Python scripts in the source tree, excluding generated result files, university reference material, and vendored tooling under `.terraform`.

If a new script is added, document it here or in a more specific README and link to that documentation from here.

## Repository Utility Scripts

| Script | Purpose |
|---|---|
| `auto_commit.sh` | One-file-per-commit helper used to commit recognised dissertation, result, and artefact files with structured commit messages while skipping unknown paths. |

## Top-Level Workflow Scripts

| Script | Purpose |
|---|---|
| `scripts/run_plaintext_workflow.sh` | Historical convenience wrapper that deploys the plaintext cluster and runs the older plaintext parameter sweep workflow. Final TLS and mTLS campaigns use the factorial executor instead. |

## Orchestration Scripts

| Script | Purpose |
|---|---|
| `scripts/orchestration/lib.sh` | Shared shell helpers for logging, required-file checks, retries, and checkpoint marking. This is sourced by other orchestration scripts and is not intended to be run directly. |
| `scripts/orchestration/export_tf_outputs.sh` | Writes Terraform outputs to `.orchestration/terraform-output.json` so later orchestration steps can build inventory and cluster metadata. |
| `scripts/orchestration/build_inventory.sh` | Converts Terraform output JSON into `.orchestration/inventory.env`, including broker and benchmark-client public/private IPs. |
| `scripts/orchestration/build_cluster_metadata.sh` | Builds `.orchestration/cluster.env`, including Kafka bootstrap servers, KRaft controller voters, and broker count. |
| `scripts/orchestration/prepare_benchmark_client.sh` | Installs Kafka client tooling, telemetry collection, plaintext client config, and benchmark runner scripts on the benchmark-client host. |
| `scripts/orchestration/generate_tls_assets.sh` | Generates the local CA, broker keystores, client keystores, truststores, and TLS environment file used by TLS and mTLS deployments. |
| `scripts/orchestration/prepare_tls_benchmark_client.sh` | Installs TLS truststore material and generated TLS client properties on the benchmark-client host. |
| `scripts/orchestration/prepare_mtls_benchmark_client.sh` | Installs mTLS truststore, client keystore, and generated mTLS client properties on the benchmark-client host. |
| `scripts/orchestration/bootstrap_brokers.sh` | Copies plaintext broker bootstrap assets to EC2 broker hosts, installs Kafka, writes broker config, formats KRaft storage, and starts Kafka. |
| `scripts/orchestration/bootstrap_tls_brokers.sh` | Bootstraps brokers for TLS mode by installing Kafka, copying broker TLS assets, configuring TLS listeners, and validating service readiness. |
| `scripts/orchestration/bootstrap_mtls_brokers.sh` | Bootstraps brokers for mTLS mode by installing Kafka, copying mutual-auth TLS assets, configuring client-certificate authentication, and validating readiness. |
| `scripts/orchestration/deploy_plaintext_cluster.sh` | Checkpointed deployment flow for plaintext Kafka: export Terraform outputs, build inventory/metadata, prepare benchmark client, and bootstrap brokers. |
| `scripts/orchestration/deploy_tls_cluster.sh` | Checkpointed deployment flow for TLS Kafka: export outputs, build inventory/metadata, generate TLS assets, prepare client config, and bootstrap TLS brokers. |
| `scripts/orchestration/deploy_mtls_cluster.sh` | Checkpointed deployment flow for mTLS Kafka: export outputs, build inventory/metadata, generate TLS assets, prepare mTLS client config, and bootstrap mTLS brokers. |
| `scripts/orchestration/prepare_broker_count_phase.sh` | Switches the Terraform broker-count phase between 3 and 5 brokers, applies the infrastructure change, refreshes orchestration metadata, and optionally resets Kafka storage. |
| `scripts/orchestration/generate_factorial_plan.sh` | Expands a factorial JSON configuration into a JSONL execution plan with deterministic run identifiers and Kafka-valid broker/replication/minISR combinations. |
| `scripts/orchestration/run_factorial_plan.sh` | Main final-campaign executor. It filters JSONL plan rows, skips completed runs, executes producer or consumer benchmarks remotely, collects telemetry, parses outputs, aggregates summaries, and exports comparison artefacts. |
| `scripts/orchestration/run_parameter_sweep.sh` | Older plaintext sweep executor that expands a baseline plus one sweep variable into remote producer benchmark runs. Retained as historical validation tooling. |
| `scripts/orchestration/parse_producer_perf_results.sh` | Parses a producer run directory into `result.json`, combining raw Kafka producer-perf output, metadata, concurrent-producer diagnostics, interval latency diagnostics, and host telemetry summaries. |
| `scripts/orchestration/parse_consumer_perf_results.sh` | Parses a consumer run directory into `result.json`, combining Kafka consumer-perf CSV output, metadata, and host telemetry summaries. |
| `scripts/orchestration/aggregate_sweep_results.sh` | Aggregates per-run `result.json` files into campaign-level `summary.json` and `summary.csv`, including started/completed/failure counts. |

## Analysis And Export Scripts

| Script | Purpose |
|---|---|
| `scripts/analysis/export_sweep_artifacts.sh` | Thin shell wrapper for `export_sweep_artifacts.py`; expects a `summary.json` path. |
| `scripts/analysis/export_sweep_artifacts.py` | Produces sweep-level CSV tables, LaTeX tables, and SVG plots from an aggregated `summary.json`. |
| `scripts/analysis/export_security_comparison.sh` | Thin shell wrapper for `export_security_comparison.py`; expects an output directory followed by matched summary CSV inputs. |
| `scripts/analysis/export_security_comparison.py` | Joins matched plaintext/TLS/mTLS summary rows and exports security-overhead CSV tables, LaTeX tables, and SVG plots. |
| `scripts/analysis/export_final_phase_comparison.sh` | Convenience exporter for canonical final producer phases. It locates broker-3 or broker-5 plaintext/TLS/mTLS summaries and calls the security comparison exporter. |
| `scripts/analysis/export_consumer_slice_comparison.sh` | Convenience exporter for the targeted consumer validation slice. It locates canonical consumer plaintext/TLS/mTLS summaries and calls the security comparison exporter. |
| `scripts/analysis/export_comprehensive_final_results.py` | Generates a broad final result pack from producer and consumer summaries, including combined CSV data, LaTeX-ready tables, PNG/PDF figures, and a manifest. |
| `scripts/analysis/export_statistical_analysis.py` | Generates bootstrap confidence intervals, matched-pair effect summaries, factor-sensitivity CSV tables, and LaTeX-ready statistical tables from the final matched producer and consumer comparison files. |

## Remote Kafka Bootstrap Scripts

These scripts are copied to EC2 hosts by orchestration scripts and run remotely with elevated privileges.

| Script | Purpose |
|---|---|
| `deploy/kafka/bootstrap/install_kafka.sh` | Installs Java and Kafka server binaries, creates the `kafka` user/group, and prepares Kafka directories on broker hosts. |
| `deploy/kafka/bootstrap/install_kafka_client.sh` | Installs Java, Kafka client tooling, `jq`, and result directories on the benchmark-client host. |
| `deploy/kafka/bootstrap/generate_cluster_id.sh` | Generates and stores a Kafka KRaft cluster ID if one is not already present. |
| `deploy/kafka/bootstrap/configure_kafka_plaintext.sh` | Renders plaintext `server.properties`, formats Kafka storage with the cluster ID, and prepares the broker for plaintext mode. |
| `deploy/kafka/bootstrap/configure_kafka_tls.sh` | Renders TLS or mTLS `server.properties`, validates required keystores/truststores, formats Kafka storage, and prepares the broker for secure transport. |
| `deploy/kafka/bootstrap/create_systemd_service.sh` | Writes and enables the `kafka.service` systemd unit used to start and stop brokers. |

## Remote Benchmark And Telemetry Scripts

These scripts are installed on the benchmark-client or broker hosts and invoked by the orchestration layer.

| Script | Purpose |
|---|---|
| `deploy/kafka/client/run_plaintext_producer_perf.sh` | Runs Kafka producer performance tests for plaintext, TLS, or mTLS depending on `SECURITY_MODE` and `CLIENT_CONFIG`; supports concurrent producers, topic lifecycle logs, metadata capture, and raw producer logs. |
| `deploy/kafka/client/run_consumer_perf.sh` | Seeds a benchmark topic, runs Kafka consumer performance tests, records topic lifecycle logs, metadata, producer-seed logs, and raw consumer output. |
| `deploy/kafka/common/collect_host_telemetry.sh` | Long-running telemetry sampler that writes newline-delimited JSON for CPU, memory, network, and disk counters until stopped by the executor. |

## Coverage Check

The source-script inventory used for this index is:

```bash
rg --files -g '*.sh' -g '*.py' -g '!results/**' -g '!uni_stuff/**'
```

Executable binaries under `infrastructure/terraform/envs/dev/.terraform/` are provider tooling, not repository scripts, and are intentionally excluded from this index.
