# Reproducibility

## Goal

The artefact should allow another person to rerun the same benchmark scenarios and obtain comparable results under the same environment assumptions.

## Reproducibility Requirements

Each run should capture:

- timestamp
- software versions
- Kafka image or binary version
- scenario identifier
- workload identifier
- security mode
- topic settings
- broker settings relevant to the run
- benchmark client settings

## Environment Control

To reduce noise:

- use the same machine or document hardware differences
- avoid concurrent heavy workloads on the host
- keep container resource settings stable if configured
- document whether runs are local, VM-based, or container-based

## Output Requirements

Results should be stored in structured files, ideally one directory per run containing:

- raw benchmark output
- parsed metrics
- run metadata
- any error logs

## Run Identification

Each run should have a unique run identifier so dissertation figures can be traced back to raw artefacts.

Example structure:

```text
results/
  2026-04-14T120000Z_plaintext_low/
  2026-04-14T121500Z_tls_low/
  2026-04-14T123000Z_mtls_low/
```

## Repeatability Strategy

Where feasible:

- repeat each scenario multiple times
- record summary statistics later during analysis
- note anomalies rather than silently discarding them

## Reproducibility Boundary

The goal is reproducible benchmarking procedure, not bit-identical measurements. Small runtime variance is expected, but the workflow, configuration, and interpretation should remain stable and auditable.
