# Plaintext Workflow Command

This is a historical plaintext-only workflow note. It remains useful for early one-factor validation, but final dissertation security-overhead runs now use the resumable factorial executor documented in `docs/final-campaign-operating-notes.md`.

## Goal

This command ran the early plaintext artefact workflow end to end:

1. deploy or resume the plaintext Kafka cluster setup
2. execute the selected parameter sweep
3. aggregate sweep results
4. export dissertation-ready tables and plots

## Command

```bash
SSH_KEY_PATH=/path/to/key.pem scripts/run_plaintext_workflow.sh
```

## Selecting a Sweep

The workflow defaults to:

- `config/sweeps/message_size_bytes.json`

To override the sweep:

```bash
SSH_KEY_PATH=/path/to/key.pem \
SWEEP_FILE=config/sweeps/target_messages_per_second.json \
scripts/run_plaintext_workflow.sh
```

## Outputs

The workflow writes results under:

- `results/<sweep-name>/`

Each sweep directory contains:

- per-run raw logs and structured results
- `summary.json`
- `summary.csv`
- `export/` with CSV, LaTeX, and SVG artifacts

## Current Boundary

This command currently supports only plaintext execution. TLS and mTLS should later plug into the same top-level workflow rather than adding separate user-facing commands.
