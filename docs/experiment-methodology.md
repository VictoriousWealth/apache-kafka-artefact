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
