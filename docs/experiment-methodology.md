# Experiment Methodology

## Aim

The framework is designed to support controlled measurement of the performance impact of Kafka transport security mechanisms, especially TLS and mTLS.

The methodology uses custom synthetic workloads instead of a standard benchmark suite. This is because the dissertation requires direct, controlled comparison of transport security modes under a small number of justified and transparent workload classes.

## Method

The artefact uses a one-factor-at-a-time methodology.

For each experiment:

- One selected independent variable is changed
- All other relevant variables are held constant
- The workload is executed under repeatable conditions
- The resulting metrics are recorded in a structured format

This is intended to isolate causal effects and reduce confounding between security changes and unrelated system changes.

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
- `cpu_usage` if collected
- `memory_usage` if collected

## Metrics

### Primary Metric

Throughput is the primary metric because the dissertation rubric explicitly requires it.

Possible reporting units:

- messages per second
- bytes per second
- megabytes per second

### Secondary Metrics

Latency is the main secondary metric because security overhead may affect queueing delay and end-to-end responsiveness.

Optional host-level metrics:

- CPU usage
- memory usage

## Fairness Controls

To support valid comparisons:

- identical hardware or host environment must be used across scenarios
- non-security Kafka settings must remain fixed for baseline comparisons
- the same workload definitions must be applied to all security modes
- warm-up effects should be handled consistently
- each scenario should be repeated multiple times when practical

## Workload Design

The framework should support at least three workload classes:

- `low`
- `medium`
- `high`

Each workload should define at minimum:

- message size
- target message rate or producer intensity
- producer count
- consumer count
- batching-related settings if used

These workloads are synthetic by design. They do not attempt to reproduce a single real business workload. Instead, they provide controlled traffic profiles that make it possible to isolate how Kafka security and deployment parameters affect throughput and latency.

The dissertation does not need to report every possible workload combination. It should report a justified subset that is representative and manageable.

## Experiment Lifecycle

1. Select a scenario definition.
2. Start Kafka in the correct security mode.
3. Verify topic and broker readiness.
4. Apply workload parameters.
5. Run producer and consumer benchmarks.
6. Collect benchmark and environment metrics.
7. Persist outputs with metadata.
8. Reset before the next run.

## Threats to Validity to Control

The methodology should explicitly consider:

- environment noise from concurrent host activity
- startup and warm-up transients
- client-side bottlenecks masquerading as broker bottlenecks
- unfair comparisons caused by changed Kafka settings outside the intended variable
- certificate or handshake setup cost being mixed incorrectly with sustained data-plane throughput

## Reporting Position for the Dissertation

The dissertation should describe the artefact as a configurable framework, but the reported evaluation should be a selected, justified subset of the framework's available parameter space.
