#!/usr/bin/env python3

from __future__ import annotations

import csv
import math
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


SECURITY_MODES = ("plaintext", "tls", "mtls")

CONFIG_FIELDS = [
    "broker_count",
    "partitions",
    "replication_factor",
    "min_insync_replicas",
    "num_records",
    "record_size_bytes",
    "throughput_limit_records_per_sec",
    "producer_count",
    "consumer_count",
    "batch_size",
    "linger_ms",
    "acks",
    "compression_type",
    "trial_index",
]

METRIC_FIELDS = [
    "throughput_records_per_sec",
    "throughput_mb_per_sec",
    "avg_latency_ms",
    "max_latency_ms",
    "benchmark_client_cpu_percent_mean",
    "broker_cpu_percent_mean",
    "broker_cpu_percent_max_mean",
]


def read_rows(summary_paths: list[Path]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for path in summary_paths:
        if not path.is_file():
            raise FileNotFoundError(f"Summary CSV not found: {path}")
        with path.open("r", newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            rows.extend(dict(row) for row in reader)
    return rows


def key_for(row: dict[str, str]) -> tuple[str, ...]:
    return tuple(row.get(field, "") for field in CONFIG_FIELDS)


def to_float(value: str | None) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() == "null":
        return None
    try:
        parsed = float(text)
    except ValueError:
        return None
    if math.isnan(parsed) or math.isinf(parsed):
        return None
    return parsed


def pct_change(candidate: float | None, baseline: float | None) -> float | None:
    if candidate is None or baseline is None or math.isclose(baseline, 0.0):
        return None
    return ((candidate - baseline) / baseline) * 100.0


def format_number(value: Any, decimals: int = 3) -> str:
    if value is None:
        return ""
    if isinstance(value, float):
        return f"{value:.{decimals}f}"
    return str(value)


def build_matches(rows: list[dict[str, str]]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, ...], dict[str, dict[str, str]]] = defaultdict(dict)
    for row in rows:
        mode = row.get("security_mode", "")
        if mode not in SECURITY_MODES:
            continue
        grouped[key_for(row)][mode] = row

    matches: list[dict[str, Any]] = []
    for key, by_mode in sorted(grouped.items()):
        if "plaintext" not in by_mode:
            continue
        if not any(mode in by_mode for mode in ("tls", "mtls")):
            continue

        config = dict(zip(CONFIG_FIELDS, key))
        item: dict[str, Any] = {"config": config, "modes": by_mode}
        matches.append(item)
    return matches


def write_comparison_csv(output_dir: Path, matches: list[dict[str, Any]]) -> Path:
    output_path = output_dir / "comparison.csv"
    fieldnames = [
        *CONFIG_FIELDS,
        "matched_modes",
        *[f"{mode}_{metric}" for mode in SECURITY_MODES for metric in METRIC_FIELDS],
        *[
            f"{mode}_{metric}_pct_vs_plaintext"
            for mode in ("tls", "mtls")
            for metric in METRIC_FIELDS
        ],
    ]

    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for match in matches:
            modes = match["modes"]
            out: dict[str, Any] = dict(match["config"])
            out["matched_modes"] = ",".join(mode for mode in SECURITY_MODES if mode in modes)

            plaintext = modes["plaintext"]
            for mode in SECURITY_MODES:
                row = modes.get(mode)
                for metric in METRIC_FIELDS:
                    out[f"{mode}_{metric}"] = row.get(metric, "") if row else ""

            for mode in ("tls", "mtls"):
                row = modes.get(mode)
                for metric in METRIC_FIELDS:
                    out[f"{mode}_{metric}_pct_vs_plaintext"] = format_number(
                        pct_change(
                            to_float(row.get(metric) if row else None),
                            to_float(plaintext.get(metric)),
                        )
                    )

            writer.writerow(out)
    return output_path


def mean(values: list[float]) -> float | None:
    if not values:
        return None
    return sum(values) / len(values)


def aggregate_overheads(matches: list[dict[str, Any]]) -> dict[str, dict[str, float | None]]:
    values: dict[str, dict[str, list[float]]] = {
        "tls": defaultdict(list),
        "mtls": defaultdict(list),
    }

    for match in matches:
        modes = match["modes"]
        plaintext = modes["plaintext"]
        for mode in ("tls", "mtls"):
            candidate = modes.get(mode)
            if not candidate:
                continue
            for metric in METRIC_FIELDS:
                delta = pct_change(to_float(candidate.get(metric)), to_float(plaintext.get(metric)))
                if delta is not None:
                    values[mode][metric].append(delta)

    return {
        mode: {metric: mean(metric_values) for metric, metric_values in by_metric.items()}
        for mode, by_metric in values.items()
    }


def write_summary_csv(output_dir: Path, matches: list[dict[str, Any]]) -> Path:
    output_path = output_dir / "summary.csv"
    aggregates = aggregate_overheads(matches)
    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["security_mode", "matched_rows", *[f"{metric}_pct_vs_plaintext_mean" for metric in METRIC_FIELDS]])
        for mode in ("tls", "mtls"):
            matched_rows = sum(1 for match in matches if mode in match["modes"])
            writer.writerow(
                [
                    mode,
                    matched_rows,
                    *[format_number(aggregates.get(mode, {}).get(metric)) for metric in METRIC_FIELDS],
                ]
            )
    return output_path


def write_table_tex(output_dir: Path, matches: list[dict[str, Any]]) -> Path:
    output_path = output_dir / "table.tex"
    aggregates = aggregate_overheads(matches)
    lines = [
        r"\begin{tabular}{lrrrrr}",
        r"\hline",
        r"Mode & Rows & Throughput \% & Avg lat. \% & Max lat. \% & Broker CPU \% \\",
        r"\hline",
    ]
    for mode in ("tls", "mtls"):
        rows = sum(1 for match in matches if mode in match["modes"])
        mode_values = aggregates.get(mode, {})
        lines.append(
            " & ".join(
                [
                    mode.upper(),
                    str(rows),
                    format_number(mode_values.get("throughput_records_per_sec")),
                    format_number(mode_values.get("avg_latency_ms")),
                    format_number(mode_values.get("max_latency_ms")),
                    format_number(mode_values.get("broker_cpu_percent_mean")),
                ]
            )
            + r" \\"
        )
    lines.extend([r"\hline", r"\end{tabular}"])
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output_path


def svg_bar_plot(output_path: Path, title: str, values: dict[str, float | None], ylabel: str) -> None:
    width = 760
    height = 460
    margin_left = 90
    margin_right = 40
    margin_top = 54
    margin_bottom = 80
    plot_width = width - margin_left - margin_right
    plot_height = height - margin_top - margin_bottom

    numeric_values = [value for value in values.values() if value is not None]
    if not numeric_values:
        return

    min_value = min(0.0, min(numeric_values))
    max_value = max(0.0, max(numeric_values))
    if math.isclose(min_value, max_value):
        min_value -= 1.0
        max_value += 1.0

    def y_for(value: float) -> float:
        return margin_top + ((max_value - value) / (max_value - min_value)) * plot_height

    zero_y = y_for(0.0)
    bar_width = 110
    spacing = plot_width / 3
    colors = {"tls": "#1565c0", "mtls": "#c62828"}

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width / 2:.0f}" y="28" text-anchor="middle" font-size="20" font-family="Helvetica">{title}</text>',
        f'<line x1="{margin_left}" y1="{zero_y:.2f}" x2="{margin_left + plot_width}" y2="{zero_y:.2f}" stroke="#333" stroke-width="2"/>',
        f'<line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{margin_top + plot_height}" stroke="#333" stroke-width="2"/>',
    ]

    tick_values = [min_value + ((max_value - min_value) * step / 4.0) for step in range(5)]
    for tick in tick_values:
        y = y_for(tick)
        parts.append(f'<line x1="{margin_left}" y1="{y:.2f}" x2="{margin_left + plot_width}" y2="{y:.2f}" stroke="#e0e0e0" stroke-width="1"/>')
        parts.append(f'<text x="{margin_left - 10}" y="{y + 4:.2f}" text-anchor="end" font-size="12" font-family="Helvetica">{tick:.2f}</text>')

    for index, mode in enumerate(("tls", "mtls")):
        value = values.get(mode)
        if value is None:
            continue
        center_x = margin_left + spacing * (index + 1)
        bar_x = center_x - (bar_width / 2)
        bar_y = min(y_for(value), zero_y)
        bar_h = abs(zero_y - y_for(value))
        parts.append(f'<rect x="{bar_x:.2f}" y="{bar_y:.2f}" width="{bar_width}" height="{bar_h:.2f}" fill="{colors[mode]}"/>')
        label_y = bar_y - 8 if value >= 0 else bar_y + bar_h + 18
        parts.append(f'<text x="{center_x:.2f}" y="{label_y:.2f}" text-anchor="middle" font-size="13" font-family="Helvetica">{value:.2f}%</text>')
        parts.append(f'<text x="{center_x:.2f}" y="{height - 42}" text-anchor="middle" font-size="15" font-family="Helvetica">{mode.upper()}</text>')

    parts.append(f'<text x="22" y="{height / 2:.0f}" text-anchor="middle" font-size="14" font-family="Helvetica" transform="rotate(-90 22,{height / 2:.0f})">{ylabel}</text>')
    parts.append("</svg>")
    output_path.write_text("\n".join(parts) + "\n", encoding="utf-8")


def write_plots(output_dir: Path, matches: list[dict[str, Any]]) -> list[Path]:
    aggregates = aggregate_overheads(matches)
    plot_specs = [
        ("throughput_overhead_pct.svg", "Throughput Change vs Plaintext", "throughput_records_per_sec"),
        ("avg_latency_overhead_pct.svg", "Average Latency Change vs Plaintext", "avg_latency_ms"),
        ("max_latency_overhead_pct.svg", "Max Latency Change vs Plaintext", "max_latency_ms"),
        ("client_cpu_overhead_pct.svg", "Benchmark Client CPU Change vs Plaintext", "benchmark_client_cpu_percent_mean"),
        ("broker_cpu_overhead_pct.svg", "Broker CPU Change vs Plaintext", "broker_cpu_percent_mean"),
    ]
    generated: list[Path] = []
    for filename, title, metric in plot_specs:
        output_path = output_dir / filename
        svg_bar_plot(
            output_path,
            title,
            {mode: aggregates.get(mode, {}).get(metric) for mode in ("tls", "mtls")},
            "% change vs plaintext",
        )
        if output_path.exists():
            generated.append(output_path)
    return generated


def export(output_dir: Path, summary_paths: list[Path]) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    rows = read_rows(summary_paths)
    matches = build_matches(rows)
    if not matches:
        raise RuntimeError("No matched rows found. At minimum, plaintext and one secure mode must share the same configuration.")

    generated = [
        write_comparison_csv(output_dir, matches),
        write_summary_csv(output_dir, matches),
        write_table_tex(output_dir, matches),
    ]
    generated.extend(write_plots(output_dir, matches))
    return generated


def main(argv: list[str]) -> int:
    if len(argv) < 5:
        print(f"Usage: {argv[0]} <output-dir> <summary.csv> <summary.csv> <summary.csv> [summary.csv ...]", file=sys.stderr)
        return 1

    output_dir = Path(argv[1])
    summary_paths = [Path(arg) for arg in argv[2:]]
    try:
        generated = export(output_dir, summary_paths)
    except Exception as exc:
        print(f"Failed to export security comparison: {exc}", file=sys.stderr)
        return 1

    for path in generated:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
