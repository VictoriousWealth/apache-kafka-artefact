# Export Layer

## Goal

The export layer converts parsed benchmark summaries into artefacts that can be used directly in dissertation writing. It supports historical one-factor sweeps, matched plaintext/TLS/mTLS comparisons, the comprehensive final result pack, and statistical summaries.

## Outputs

For each historical sweep summary, the export layer writes an `export/` directory containing:

- `table.csv`
- `table.tex`
- `throughput_records_per_sec.svg`
- `throughput_mb_per_sec.svg`
- `avg_latency_ms.svg` when latency data is present
- `max_latency_ms.svg` when latency data is present

Matched security-mode exports join plaintext, TLS, and mTLS rows with identical workload and deployment fields. These exports include comparison CSV files, LaTeX summary tables, and overhead plots for throughput, latency, CPU, network, and disk metrics.

The comprehensive final result pack is written under:

```text
results/final-processed/comprehensive-result-pack/
```

It includes:

- matched producer and consumer comparison data under `data/`
- dissertation-ready CSV and LaTeX tables under `tables/`
- final figures under `figures/`
- bootstrap confidence intervals, matched-pair effect summaries, and factor-sensitivity outputs under `statistics/`
- a result-pack manifest for traceability

## Usage

The historical sweep export layer runs automatically at the end of `scripts/orchestration/run_parameter_sweep.sh`.

It can also be run manually:

```bash
scripts/analysis/export_sweep_artifacts.sh results/<sweep-name>/summary.json
```

Canonical producer phase comparisons can be regenerated with:

```bash
scripts/analysis/export_final_phase_comparison.sh --broker-count 5
scripts/analysis/export_final_phase_comparison.sh --broker-count 3
```

The final dissertation result pack can be regenerated with:

```bash
python3 scripts/analysis/export_comprehensive_final_results.py
```

The statistical export can be regenerated with:

```bash
python3 scripts/analysis/export_statistical_analysis.py
```

## Dissertation Use

- `table.csv` is suitable for spreadsheet review and manual inspection.
- `table.tex` can be adapted into a LaTeX dissertation chapter with minimal editing.
- the SVG plots are vector graphics, so they are suitable for inclusion in the dissertation without rasterisation artifacts.
- the final statistical tables should be used when reporting uncertainty, matched-pair direction, or factor sensitivity.

## Current Plot Design

The current plots visualise the grouped mean value for each tested sweep value and show min/max spread as a vertical range marker.

This is intentionally simple and dependency-light so the export layer remains portable.
