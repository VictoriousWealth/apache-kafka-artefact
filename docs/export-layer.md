# Export Layer

## Goal

The export layer converts a sweep-level `summary.json` file into artifacts that can be used directly in dissertation writing.

## Outputs

For each sweep summary, the export layer writes an `export/` directory containing:

- `table.csv`
- `table.tex`
- `throughput_records_per_sec.svg`
- `throughput_mb_per_sec.svg`
- `avg_latency_ms.svg` when latency data is present
- `max_latency_ms.svg` when latency data is present

## Usage

The export layer runs automatically at the end of `scripts/orchestration/run_parameter_sweep.sh`.

It can also be run manually:

```bash
scripts/analysis/export_sweep_artifacts.sh results/<sweep-name>/summary.json
```

## Dissertation Use

- `table.csv` is suitable for spreadsheet review and manual inspection.
- `table.tex` can be adapted into a LaTeX dissertation chapter with minimal editing.
- the SVG plots are vector graphics, so they are suitable for inclusion in the dissertation without rasterisation artifacts.

## Current Plot Design

The current plots visualise the grouped mean value for each tested sweep value and show min/max spread as a vertical range marker.

This is intentionally simple and dependency-light so the export layer remains portable.
