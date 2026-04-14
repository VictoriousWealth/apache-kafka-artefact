#!/usr/bin/env python3

from __future__ import annotations

import csv
import json
import math
import sys
from pathlib import Path
from typing import Any


def load_summary(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def ensure_export_dir(sweep_dir: Path) -> Path:
    export_dir = sweep_dir / "export"
    export_dir.mkdir(parents=True, exist_ok=True)
    return export_dir


def sort_grouped_stats(grouped_stats: list[dict[str, Any]]) -> list[dict[str, Any]]:
    def key_fn(item: dict[str, Any]) -> tuple[int, Any]:
        value = item["sweep_value"]
        if isinstance(value, (int, float)):
            return (0, value)
        return (1, str(value))

    return sorted(grouped_stats, key=key_fn)


def format_value(value: Any) -> str:
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.3f}"
    return str(value)


def write_table_csv(export_dir: Path, summary: dict[str, Any]) -> Path:
    output_path = export_dir / "table.csv"
    grouped_stats = sort_grouped_stats(summary["grouped_stats"])
    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "sweep_value",
                "run_count",
                "throughput_records_per_sec_mean",
                "throughput_records_per_sec_min",
                "throughput_records_per_sec_max",
                "throughput_mb_per_sec_mean",
                "throughput_mb_per_sec_min",
                "throughput_mb_per_sec_max",
                "avg_latency_ms_mean",
                "avg_latency_ms_min",
                "avg_latency_ms_max",
                "max_latency_ms_mean",
                "max_latency_ms_min",
                "max_latency_ms_max",
            ]
        )
        for row in grouped_stats:
            writer.writerow(
                [
                    row["sweep_value"],
                    row["run_count"],
                    row["throughput_records_per_sec"]["mean"],
                    row["throughput_records_per_sec"]["min"],
                    row["throughput_records_per_sec"]["max"],
                    row["throughput_mb_per_sec"]["mean"],
                    row["throughput_mb_per_sec"]["min"],
                    row["throughput_mb_per_sec"]["max"],
                    row["avg_latency_ms"]["mean"],
                    row["avg_latency_ms"]["min"],
                    row["avg_latency_ms"]["max"],
                    row["max_latency_ms"]["mean"],
                    row["max_latency_ms"]["min"],
                    row["max_latency_ms"]["max"],
                ]
            )
    return output_path


def write_table_tex(export_dir: Path, summary: dict[str, Any]) -> Path:
    output_path = export_dir / "table.tex"
    grouped_stats = sort_grouped_stats(summary["grouped_stats"])
    lines = [
        r"\begin{tabular}{lrrrrrr}",
        r"\hline",
        "Value & Runs & Mean rec/s & Min rec/s & Max rec/s & Mean MB/s & Mean avg lat (ms) \\",
        r"\hline",
    ]
    for row in grouped_stats:
        lines.append(
            " & ".join(
                [
                    str(row["sweep_value"]),
                    str(row["run_count"]),
                    format_value(row["throughput_records_per_sec"]["mean"]),
                    format_value(row["throughput_records_per_sec"]["min"]),
                    format_value(row["throughput_records_per_sec"]["max"]),
                    format_value(row["throughput_mb_per_sec"]["mean"]),
                    format_value(row["avg_latency_ms"]["mean"]),
                ]
            )
            + r" \\"
        )
    lines.extend([r"\hline", r"\end{tabular}"])
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output_path


def numeric_or_indexed_points(grouped_stats: list[dict[str, Any]]) -> tuple[list[float], list[str], bool]:
    if all(isinstance(item["sweep_value"], (int, float)) for item in grouped_stats):
        return [float(item["sweep_value"]) for item in grouped_stats], [str(item["sweep_value"]) for item in grouped_stats], True
    return [float(index) for index, _ in enumerate(grouped_stats)], [str(item["sweep_value"]) for item in grouped_stats], False


def scale(values: list[float], start: float, end: float) -> list[float]:
    if not values:
        return []
    min_v = min(values)
    max_v = max(values)
    if math.isclose(min_v, max_v):
        return [(start + end) / 2.0 for _ in values]
    return [start + ((value - min_v) / (max_v - min_v)) * (end - start) for value in values]


def project_value(value: float, min_v: float, max_v: float, start: float, end: float) -> float:
    if math.isclose(min_v, max_v):
        return (start + end) / 2.0
    return start + ((value - min_v) / (max_v - min_v)) * (end - start)


def build_svg_plot(
    grouped_stats: list[dict[str, Any]],
    metric_key: str,
    metric_label: str,
    output_path: Path,
) -> None:
    values = [item[metric_key]["mean"] for item in grouped_stats if item[metric_key]["mean"] is not None]
    if not values:
        return

    width = 900
    height = 520
    margin_left = 90
    margin_right = 30
    margin_top = 40
    margin_bottom = 90
    plot_width = width - margin_left - margin_right
    plot_height = height - margin_top - margin_bottom

    x_values, labels, numeric_axis = numeric_or_indexed_points(grouped_stats)
    y_values = [float(item[metric_key]["mean"]) if item[metric_key]["mean"] is not None else math.nan for item in grouped_stats]
    x_scaled = scale(x_values, margin_left, margin_left + plot_width)
    valid_y = [value for value in y_values if not math.isnan(value)]
    y_scaled = scale(valid_y, margin_top + plot_height, margin_top)

    y_map: list[float] = []
    idx = 0
    for value in y_values:
        if math.isnan(value):
            y_map.append(math.nan)
        else:
            y_map.append(y_scaled[idx])
            idx += 1

    polyline_points = " ".join(
        f"{x:.2f},{y:.2f}" for x, y in zip(x_scaled, y_map) if not math.isnan(y)
    )

    y_min = min(valid_y)
    y_max = max(valid_y)
    tick_values = [y_min + ((y_max - y_min) * step / 4.0) for step in range(5)] if not math.isclose(y_min, y_max) else [y_min]
    tick_positions = scale(tick_values, margin_top + plot_height, margin_top)

    parts: list[str] = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width/2:.0f}" y="24" text-anchor="middle" font-size="20" font-family="Helvetica">{metric_label}</text>',
        f'<line x1="{margin_left}" y1="{margin_top + plot_height}" x2="{margin_left + plot_width}" y2="{margin_top + plot_height}" stroke="#333" stroke-width="2"/>',
        f'<line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{margin_top + plot_height}" stroke="#333" stroke-width="2"/>',
    ]

    for tick_value, tick_y in zip(tick_values, tick_positions):
        parts.append(
            f'<line x1="{margin_left}" y1="{tick_y:.2f}" x2="{margin_left + plot_width}" y2="{tick_y:.2f}" stroke="#e0e0e0" stroke-width="1"/>'
        )
        parts.append(
            f'<text x="{margin_left - 10}" y="{tick_y + 4:.2f}" text-anchor="end" font-size="12" font-family="Helvetica">{tick_value:.2f}</text>'
        )

    if polyline_points:
        parts.append(f'<polyline fill="none" stroke="#1565c0" stroke-width="3" points="{polyline_points}"/>')

    for item, x, y, label in zip(grouped_stats, x_scaled, y_map, labels):
        if math.isnan(y):
            continue
        min_value = item[metric_key]["min"]
        max_value = item[metric_key]["max"]
        min_y = project_value(float(min_value), y_min, y_max, margin_top + plot_height, margin_top) if min_value is not None else y
        max_y = project_value(float(max_value), y_min, y_max, margin_top + plot_height, margin_top) if max_value is not None else y
        parts.append(f'<line x1="{x:.2f}" y1="{min_y:.2f}" x2="{x:.2f}" y2="{max_y:.2f}" stroke="#90caf9" stroke-width="2"/>')
        parts.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="4" fill="#0d47a1"/>')
        parts.append(
            f'<text x="{x:.2f}" y="{margin_top + plot_height + 22}" text-anchor="middle" font-size="12" font-family="Helvetica" transform="rotate(35 {x:.2f},{margin_top + plot_height + 22})">{label}</text>'
        )

    x_axis_label = "Sweep value" if numeric_axis else "Sweep category"
    parts.append(
        f'<text x="{width/2:.0f}" y="{height - 20}" text-anchor="middle" font-size="14" font-family="Helvetica">{x_axis_label}</text>'
    )
    parts.append(
        f'<text x="20" y="{height/2:.0f}" text-anchor="middle" font-size="14" font-family="Helvetica" transform="rotate(-90 20,{height/2:.0f})">{metric_label}</text>'
    )
    parts.append("</svg>")
    output_path.write_text("\n".join(parts) + "\n", encoding="utf-8")


def export(summary_path: Path) -> list[Path]:
    summary = load_summary(summary_path)
    sweep_dir = summary_path.parent
    export_dir = ensure_export_dir(sweep_dir)
    grouped_stats = sort_grouped_stats(summary["grouped_stats"])

    generated = [
        write_table_csv(export_dir, summary),
        write_table_tex(export_dir, summary),
    ]

    throughput_plot = export_dir / "throughput_records_per_sec.svg"
    build_svg_plot(grouped_stats, "throughput_records_per_sec", "Mean Throughput (records/sec)", throughput_plot)
    if throughput_plot.exists():
        generated.append(throughput_plot)

    throughput_mb_plot = export_dir / "throughput_mb_per_sec.svg"
    build_svg_plot(grouped_stats, "throughput_mb_per_sec", "Mean Throughput (MB/sec)", throughput_mb_plot)
    if throughput_mb_plot.exists():
        generated.append(throughput_mb_plot)

    avg_latency_plot = export_dir / "avg_latency_ms.svg"
    build_svg_plot(grouped_stats, "avg_latency_ms", "Mean Average Latency (ms)", avg_latency_plot)
    if avg_latency_plot.exists():
        generated.append(avg_latency_plot)

    max_latency_plot = export_dir / "max_latency_ms.svg"
    build_svg_plot(grouped_stats, "max_latency_ms", "Mean Max Latency (ms)", max_latency_plot)
    if max_latency_plot.exists():
        generated.append(max_latency_plot)

    return generated


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"Usage: {argv[0]} <summary.json>", file=sys.stderr)
        return 1

    summary_path = Path(argv[1])
    if not summary_path.is_file():
        print(f"Summary file not found: {summary_path}", file=sys.stderr)
        return 1

    generated = export(summary_path)
    for path in generated:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
