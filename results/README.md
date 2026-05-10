# Results Directory Guide

This directory is intentionally large. It is part of the reproducibility evidence for the Kafka security benchmarking artefact, not a generated cache accidentally committed to Git.

The full repository checkout includes 100k+ files because the dissertation evidence keeps raw benchmark output, parsed metrics, telemetry, summaries, and exported tables or figures.

## How To Read This Directory

Start with the final campaign evidence, then use older smoke and sweep folders only as implementation history.

| Area | Purpose | How to treat it |
| --- | --- | --- |
| `factorial-final/` | Main final producer campaign evidence across plaintext, TLS, and mTLS phases | Primary evidence for final producer-side comparisons |
| `final-processed/` | Curated final tables, processed exports, and dissertation-ready outputs where present | Fastest route to headline outputs after reading the main README |
| `consumer-slice/` | Targeted consumer-side validation runs | Secondary evidence for consumer-side behaviour |
| `security-comparison-smoke/` | Early security comparison exports | Historical validation, not final conclusion source |
| `tls-smoke/`, `mtls-smoke/`, `telemetry-smoke/`, `smoke/` | Smoke tests used while validating deployments, telemetry and orchestration | Useful for development traceability, not the headline result set |
| `plaintext-requested/`, `plaintext-full/`, `plaintext-full-fixed/`, `message-size-bytes/` | Earlier plaintext sweep/factorial work | Historical design and implementation evidence |

## Final Campaign Completion Model

The final producer-side campaign should be interpreted through:

- `started.jsonl`: rows that were attempted.
- `completed.jsonl`: rows that completed successfully.
- `failures.jsonl`: failed attempts, where present.
- per-run `metadata.json`: workload/security/deployment configuration.
- per-run `result.json`: parsed benchmark metrics.
- per-run `producer-perf.log`: raw Kafka producer performance output.
- per-run `host-telemetry/*.jsonl`: raw benchmark client and broker telemetry where enabled.
- `summary.csv` and `summary.json`: phase-level aggregation.

Some failed attempts were later rerun successfully. For completion, treat `completed.jsonl` plus the presence of per-run `result.json` as the authoritative record.

## Why Raw Logs Are Included

Keeping raw logs makes the artefact more defensible:

- The parsed metrics can be traced back to Kafka benchmark output.
- Telemetry-backed comparisons can be audited.
- The dissertation result tables are reproducible from stored run artefacts.
- Failed and rerun attempts remain visible instead of being silently hidden.

## Security Hygiene

The repository history was rewritten after a credential hygiene audit. After the local rewrite:

- `gitleaks detect --source . --no-banner --redact` completed with `no leaks found`.
- Terraform state, local variable files, `.orchestration/`, `.venv/`, PEM keys, certificates, keystores, and truststores are ignored.

Before making the repository public, force-push the cleaned history and rerun secret scanners such as `gitleaks` or `trufflehog` against a fresh clone. Do not add live infrastructure state, SSH keys, generated TLS assets, `.env` files, or Terraform state to this directory.

## Lightweight Review Path

If you only want to understand the project without checking out the full evidence set, use sparse checkout from the repository root:

```bash
git clone --filter=blob:none --sparse https://github.com/VictoriousWealth/apache-kafka-artefact.git
cd apache-kafka-artefact
git sparse-checkout set --no-cone \
  'README.md' \
  'docs/**' \
  'infrastructure/**' \
  'scripts/**' \
  'config/**' \
  'deploy/**' \
  'results/README.md'
```

If you are verifying the dissertation artefact, clone normally and inspect the final campaign folders listed above.
