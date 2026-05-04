# Reproducibility

## Goal

The artefact should allow another person to rerun the same benchmark baselines and sweeps and obtain comparable results under the same environment assumptions.

The public repository location is:

```text
https://github.com/VictoriousWealth/apache-kafka-artefact
```

For dissertation submission, the submitted PDF should record either this repository URL plus a release tag or this repository URL plus the exact commit hash used to generate the final result pack.

## Reproducibility Requirements

Each run should capture:

- timestamp
- software versions
- Kafka image or binary version
- baseline identifier
- sweep identifier
- sweep variable and value
- security mode
- topic settings
- broker settings relevant to the run
- benchmark client settings

## Environment Control

To reduce noise:

- use the same EC2 instance types or document hardware differences
- avoid concurrent heavy workloads on the benchmark client or broker hosts
- keep storage, region, and network placement stable across runs
- document the AWS region, AMI, instance type, and EBS layout used

## Output Requirements

Results should be stored in structured files, ideally one directory per run containing:

- raw benchmark output
- parsed metrics
- run metadata
- any error logs

The canonical final dissertation result pack is:

```text
results/final-processed/comprehensive-result-pack/
```

This pack contains matched producer and consumer comparison CSV files, dissertation-ready tables and figures, and statistical outputs under `statistics/`. The statistical manifest records the generation settings used for bootstrap confidence intervals and factor-sensitivity summaries.

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

- repeat each sweep value multiple times where practical
- record summary statistics later during analysis
- note anomalies rather than silently discarding them

For long-running campaigns, retain both the completion ledger and the failure ledger. A row that fails transiently and is later rerun successfully should remain traceable in the execution history rather than being erased from the audit trail.

Final campaign reporting should therefore distinguish between failed attempts and unresolved missing rows. `completed.jsonl`, local `result.json` files, and matched comparison outputs are the authoritative evidence for rows included in the dissertation analysis.

## Reproducibility Boundary

The goal is reproducible benchmarking procedure, not bit-identical measurements. Small runtime variance is expected, but the workflow, configuration, and interpretation should remain stable and auditable.
