# Experiment Methodology

## Aim

The framework is designed to support controlled measurement of the performance impact of Kafka transport security mechanisms, especially TLS and mTLS.

The methodology uses custom synthetic workloads instead of a standard benchmark suite. This is because the dissertation requires direct, controlled comparison of transport security modes under justified and transparent workload classes.

## Method

The artefact supports two experiment styles:

- one-factor-at-a-time sweeps for early validation and isolated parameter checks
- selected factorial plans for the final security-overhead campaign

For each run:

- the complete Kafka and workload configuration is recorded
- the workload is executed under repeatable conditions
- producer performance metrics are recorded in a structured format
- host telemetry is sampled during the run

The final campaign uses matched configurations across plaintext, TLS, and mTLS so security overhead can be calculated from comparable runs rather than from unrelated benchmark conditions.

## Variable Model

### Primary Independent Variable

- `security_mode`
  - `plaintext`
  - `tls`
  - `mtls`

### Secondary Controllable Variables

- `broker_count`
- `partition_count`
- `replication_factor`
- `message_size`
- `message_rate`
- `producer_count`
- `consumer_count`
- `batch_size`
- `linger_ms`
- `acks`

### Dependent Variables

- `throughput`
- `latency`
- `cpu_usage`
- `memory_usage`
- `network_io`
- `disk_io`

## Metrics

### Primary Metric

Throughput is the primary metric because the dissertation rubric explicitly requires it.

Possible reporting units:

- messages per second
- bytes per second
- megabytes per second

### Secondary Metrics

Latency is the main secondary metric because security overhead may affect queueing delay and end-to-end responsiveness.

Host-level metrics:

- CPU usage
- memory usage
- network RX/TX bytes
- disk read/write sectors

CPU usage is the most important host-level metric because the dissertation's theoretical argument links cryptographic processing overhead to utilisation-driven latency growth.

The implementation records these metrics per benchmark run for the benchmark client and every active broker. Aggregated summaries expose benchmark-client CPU, broker CPU, memory usage, network byte deltas, and disk sector deltas so throughput/latency changes can be interpreted alongside resource utilisation.

The framework also records producer-spread diagnostics for concurrent producer runs, including observed producer count, min/max per-producer throughput, and min/max per-producer average latency. This prevents a multi-producer average from hiding one overloaded producer process.

Kafka producer-perf does not provide true per-record p95/p99 latency in the current runner. The parser therefore records interval-derived p95/p99 diagnostics from producer-perf interval summary lines. These must be described as interval-level latency diagnostics, not as true event-level latency percentiles.

Run reliability is part of the measurement model. Phase summaries include started, completed, and failed run counts, and failed runs remain in `failures.jsonl` rather than being silently discarded.

Consumer-side measurement is handled as a targeted validation slice. The consumer runner seeds a topic with producer-perf and then measures consumer-perf throughput, records consumed, rebalance time, and fetch time under the same `plaintext`, `tls`, and `mtls` client configurations. This is deliberately separate from the main producer factorial campaign because a full consumer factorial would multiply the campaign size without being necessary to answer the primary producer write-path overhead question.

## Fairness Controls

To support valid comparisons:

- identical hardware or host environment must be used across scenarios
- non-security Kafka settings must remain fixed for baseline comparisons
- the same workload definitions must be applied to all security modes
- warm-up effects should be handled consistently
- each scenario should be repeated multiple times when practical

## Baselines and Sweeps

The framework should define:

- baseline configurations
- sweep definitions

A baseline captures the fixed reference configuration for a set of runs.

A sweep definition captures:

- the variable being varied
- the range of values to test

This allows one concrete run to be generated per sweep value while all remaining parameters stay fixed.

## Experiment Lifecycle

1. Select a baseline configuration.
2. Select a sweep definition.
3. Resolve one concrete run from the current sweep value.
4. Start Kafka in the correct security mode.
5. Verify topic and broker readiness.
6. Apply benchmark parameters.
7. Run producer and consumer benchmarks.
8. Collect benchmark and environment metrics.
9. Persist outputs with metadata.
10. Repeat for the next sweep value.

## Threats to Validity to Control

The methodology should explicitly consider:

- environment noise from concurrent host activity
- startup and warm-up transients
- client-side bottlenecks masquerading as broker bottlenecks
- unfair comparisons caused by changed Kafka settings outside the intended variable
- certificate or handshake setup cost being mixed incorrectly with sustained data-plane throughput
- missing telemetry samples on one or more hosts
- telemetry overhead affecting benchmark results

## Reporting Position for the Dissertation

The dissertation should describe the artefact as a configurable benchmark framework supporting sweeps and factorial campaign execution. The reported evaluation should use matched plaintext/TLS/mTLS configurations from the reduced final campaign and should discuss host telemetry alongside Kafka throughput and latency.
