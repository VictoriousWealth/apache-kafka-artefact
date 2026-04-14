# Kafka Security Benchmarking Artefact

This repository contains the implementation plan and supporting documentation for a dissertation artefact focused on measuring the performance trade-offs introduced by transport security in Apache Kafka.

The artefact is defined as:

> A configurable Kafka benchmarking framework that supports controlled one-factor-at-a-time evaluation of security and deployment parameters, with primary emphasis on quantifying throughput and latency overhead under plaintext, TLS, and mTLS configurations.

## Current Status

The repository is currently in the planning and architecture stage. The dissertation draft and source material remain in the repository root, while the artefact implementation will be developed in the project structure below.

## Research Goal

The primary research question is:

> What is the performance overhead introduced by zero-trust-inspired security mechanisms, particularly mTLS, in high-throughput Kafka-based distributed systems?

To answer this, the artefact will provide:

- A reproducible Kafka deployment environment
- Security modes for `plaintext`, `TLS`, and `mTLS`
- Configurable workloads for producers and consumers
- An automated experiment runner
- Structured results suitable for later statistical analysis and dissertation figures

## Methodological Position

The framework uses a controlled one-factor-at-a-time methodology:

- One independent variable is changed per experiment run
- All remaining conditions are kept fixed
- Throughput is treated as the primary metric
- Latency is treated as a secondary metric
- Additional host metrics such as CPU and memory may be included if feasible

This keeps the artefact aligned with the dissertation rubric, which requires realism, repeatability, and rigorous benchmarking under multiple workloads.

## Planned Repository Structure

```text
README.md
docs/
  architecture.md
  experiment-methodology.md
  experiment-matrix.md
  reproducibility.md
  thesis-mapping.md
deploy/
  kafka/
  certs/
scripts/
config/
  scenarios/
  workloads/
results/
src/
  producer/
  consumer/
  controller/
```

## Documentation

The design package is split into:

- `docs/architecture.md`: system structure, components, and execution flow
- `docs/experiment-methodology.md`: benchmarking method and validity controls
- `docs/experiment-matrix.md`: first-pass scenario definitions
- `docs/reproducibility.md`: environment and rerun guidance
- `docs/thesis-mapping.md`: how the artefact supports the dissertation rubric and chapters

## Immediate Next Steps

1. Implement the baseline Kafka deployment in plaintext mode.
2. Add TLS and mTLS configuration paths and certificate generation.
3. Add benchmark workload generation and an experiment controller.
4. Persist results as structured outputs for later analysis.
