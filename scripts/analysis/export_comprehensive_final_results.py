#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
import re
import warnings
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from pandas.errors import PerformanceWarning

warnings.simplefilter("ignore", PerformanceWarning)


SECURITY_ORDER = ["plaintext", "tls", "mtls"]
SECURE_MODES = ["tls", "mtls"]

PRODUCER_RESULT_SETS = {
    "plaintext_broker5": "results/factorial-final/security-overhead-final-plaintext-broker5/summary.csv",
    "tls_broker5": "results/factorial-final/security-overhead-final-tls-broker5/summary.csv",
    "mtls_broker5": "results/factorial-final/security-overhead-final-mtls-broker5/summary.csv",
    "plaintext_broker3": "results/factorial-final/security-overhead-final-plaintext-broker3/summary.csv",
    "tls_broker3": "results/factorial-final/security-overhead-final-tls-broker3/summary.csv",
    "mtls_broker3": "results/factorial-final/security-overhead-final-mtls-broker3/summary.csv",
}

CONSUMER_RESULT_SETS = {
    "plaintext_broker5": "results/consumer-slice/consumer-security-slice-plaintext-broker5/summary.csv",
    "tls_broker5": "results/consumer-slice/consumer-security-slice-tls-broker5/summary.csv",
    "mtls_broker5": "results/consumer-slice/consumer-security-slice-mtls-broker5/summary.csv",
}

COMPLETION_SETS = {
    **{
        name: str(Path(path).parent)
        for name, path in PRODUCER_RESULT_SETS.items()
    },
    **{
        f"consumer_{name}": str(Path(path).parent)
        for name, path in CONSUMER_RESULT_SETS.items()
    },
}

KEY_FIELDS = [
    "benchmark_type",
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

NUMERIC_KEY_FIELDS = [
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
    "trial_index",
]

PRODUCER_FACTORS = [
    "broker_count",
    "replication_factor",
    "min_insync_replicas",
    "record_size_bytes",
    "throughput_limit_records_per_sec",
    "batch_size",
    "acks",
    "producer_count",
    "compression_type",
]

CONSUMER_FACTORS = [
    "record_size_bytes",
    "compression_type",
    "consumer_count",
    "throughput_limit_records_per_sec",
    "trial_index",
]

METRIC_LABELS = {
    "throughput_records_per_sec": "Throughput records/s",
    "throughput_mb_per_sec": "Throughput MB/s",
    "data_consumed_mb": "Data consumed MB",
    "avg_latency_ms": "Average latency ms",
    "max_latency_ms": "Maximum latency ms",
    "rebalance_time_ms": "Consumer rebalance time ms",
    "fetch_time_ms": "Consumer fetch time ms",
    "producer_throughput_records_per_sec_min": "Producer shard min throughput records/s",
    "producer_throughput_records_per_sec_max": "Producer shard max throughput records/s",
    "producer_avg_latency_ms_min": "Producer shard min avg latency ms",
    "producer_avg_latency_ms_max": "Producer shard max avg latency ms",
    "interval_avg_latency_ms_p95": "Interval avg latency p95 diagnostic",
    "interval_avg_latency_ms_p99": "Interval avg latency p99 diagnostic",
    "interval_max_latency_ms_p95": "Interval max latency p95 diagnostic",
    "interval_max_latency_ms_p99": "Interval max latency p99 diagnostic",
    "telemetry_host_count": "Telemetry host count",
    "benchmark_client_cpu_percent_mean": "Benchmark client CPU %",
    "broker_cpu_percent_mean": "Broker CPU mean %",
    "broker_cpu_percent_max_mean": "Broker CPU max mean %",
    "benchmark_client_memory_used_percent_mean": "Benchmark client memory %",
    "broker_memory_used_percent_mean": "Broker memory %",
    "benchmark_client_network_rx_bytes_delta": "Benchmark client network RX bytes",
    "benchmark_client_network_tx_bytes_delta": "Benchmark client network TX bytes",
    "broker_network_rx_bytes_delta_mean": "Broker network RX bytes mean",
    "broker_network_tx_bytes_delta_mean": "Broker network TX bytes mean",
    "broker_network_rx_bytes_delta_total": "Broker network RX bytes total",
    "broker_network_tx_bytes_delta_total": "Broker network TX bytes total",
    "benchmark_client_disk_read_sectors_delta": "Benchmark client disk read sectors",
    "benchmark_client_disk_write_sectors_delta": "Benchmark client disk write sectors",
    "broker_disk_read_sectors_delta_mean": "Broker disk read sectors mean",
    "broker_disk_write_sectors_delta_mean": "Broker disk write sectors mean",
    "broker_disk_read_sectors_delta_total": "Broker disk read sectors total",
    "broker_disk_write_sectors_delta_total": "Broker disk write sectors total",
}

PRODUCER_METRICS = [
    "throughput_records_per_sec",
    "throughput_mb_per_sec",
    "avg_latency_ms",
    "max_latency_ms",
    "producer_throughput_records_per_sec_min",
    "producer_throughput_records_per_sec_max",
    "producer_avg_latency_ms_min",
    "producer_avg_latency_ms_max",
    "interval_avg_latency_ms_p95",
    "interval_avg_latency_ms_p99",
    "interval_max_latency_ms_p95",
    "interval_max_latency_ms_p99",
    "benchmark_client_cpu_percent_mean",
    "broker_cpu_percent_mean",
    "broker_cpu_percent_max_mean",
    "benchmark_client_memory_used_percent_mean",
    "broker_memory_used_percent_mean",
    "benchmark_client_network_rx_bytes_delta",
    "benchmark_client_network_tx_bytes_delta",
    "broker_network_rx_bytes_delta_mean",
    "broker_network_tx_bytes_delta_mean",
    "broker_network_rx_bytes_delta_total",
    "broker_network_tx_bytes_delta_total",
    "benchmark_client_disk_read_sectors_delta",
    "benchmark_client_disk_write_sectors_delta",
    "broker_disk_read_sectors_delta_mean",
    "broker_disk_write_sectors_delta_mean",
    "broker_disk_read_sectors_delta_total",
    "broker_disk_write_sectors_delta_total",
]

CONSUMER_METRICS = [
    "records_consumed",
    "throughput_records_per_sec",
    "throughput_mb_per_sec",
    "data_consumed_mb",
    "rebalance_time_ms",
    "fetch_time_ms",
    "benchmark_client_cpu_percent_mean",
    "broker_cpu_percent_mean",
    "broker_cpu_percent_max_mean",
    "benchmark_client_memory_used_percent_mean",
    "broker_memory_used_percent_mean",
    "benchmark_client_network_rx_bytes_delta",
    "benchmark_client_network_tx_bytes_delta",
    "broker_network_rx_bytes_delta_mean",
    "broker_network_tx_bytes_delta_mean",
    "benchmark_client_disk_read_sectors_delta",
    "benchmark_client_disk_write_sectors_delta",
    "broker_disk_read_sectors_delta_mean",
    "broker_disk_write_sectors_delta_mean",
]

LOWER_IS_BETTER = {
    "avg_latency_ms",
    "max_latency_ms",
    "rebalance_time_ms",
    "fetch_time_ms",
    "producer_avg_latency_ms_min",
    "producer_avg_latency_ms_max",
    "interval_avg_latency_ms_p95",
    "interval_avg_latency_ms_p99",
    "interval_max_latency_ms_p95",
    "interval_max_latency_ms_p99",
    "benchmark_client_cpu_percent_mean",
    "broker_cpu_percent_mean",
    "broker_cpu_percent_max_mean",
    "benchmark_client_memory_used_percent_mean",
    "broker_memory_used_percent_mean",
    "benchmark_client_network_rx_bytes_delta",
    "benchmark_client_network_tx_bytes_delta",
    "broker_network_rx_bytes_delta_mean",
    "broker_network_tx_bytes_delta_mean",
    "broker_network_rx_bytes_delta_total",
    "broker_network_tx_bytes_delta_total",
    "benchmark_client_disk_read_sectors_delta",
    "benchmark_client_disk_write_sectors_delta",
    "broker_disk_read_sectors_delta_mean",
    "broker_disk_write_sectors_delta_mean",
    "broker_disk_read_sectors_delta_total",
    "broker_disk_write_sectors_delta_total",
}

HIGHER_IS_BETTER = {
    "records_sent",
    "records_consumed",
    "throughput_records_per_sec",
    "throughput_mb_per_sec",
    "data_consumed_mb",
    "producer_throughput_records_per_sec_min",
    "producer_throughput_records_per_sec_max",
}


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", str(value)).strip("_").lower()


def ensure_numeric(df: pd.DataFrame, columns: Iterable[str]) -> pd.DataFrame:
    for column in columns:
        if column in df.columns:
            df[column] = pd.to_numeric(df[column], errors="coerce")
    return df


def available_metrics(df: pd.DataFrame, metrics: list[str]) -> list[str]:
    return [metric for metric in metrics if metric in df.columns and df[metric].notna().any()]


def sort_factor_values(values: Iterable[object]) -> list[object]:
    clean_values = [value for value in values if pd.notna(value)]
    try:
        return sorted(clean_values, key=lambda value: float(value))
    except (TypeError, ValueError):
        return sorted(clean_values, key=lambda value: str(value))


def metric_label(metric: str) -> str:
    return METRIC_LABELS.get(metric, metric.replace("_", " "))


class Exporter:
    def __init__(self, output_dir: Path) -> None:
        self.output_dir = output_dir
        self.tables_csv = output_dir / "tables" / "csv"
        self.tables_tex = output_dir / "tables" / "latex"
        self.figures_png = output_dir / "figures" / "png"
        self.figures_pdf = output_dir / "figures" / "pdf"
        self.data_dir = output_dir / "data"
        self.manifest: list[dict[str, str]] = []
        for directory in [
            self.tables_csv,
            self.tables_tex,
            self.figures_png,
            self.figures_pdf,
            self.data_dir,
        ]:
            directory.mkdir(parents=True, exist_ok=True)

    def rel(self, path: Path) -> str:
        return str(path.relative_to(self.output_dir))

    def record(self, path: Path, category: str, dataset: str, name: str, description: str) -> None:
        self.manifest.append(
            {
                "path": self.rel(path),
                "category": category,
                "dataset": dataset,
                "name": name,
                "description": description,
            }
        )

    def write_data(self, name: str, df: pd.DataFrame, description: str) -> Path:
        path = self.data_dir / f"{safe_name(name)}.csv"
        df.to_csv(path, index=False)
        self.record(path, "data_csv", "combined", name, description)
        return path

    def write_table(self, name: str, df: pd.DataFrame, description: str, max_latex_rows: int = 120) -> tuple[Path, Path | None]:
        csv_path = self.tables_csv / f"{safe_name(name)}.csv"
        df.to_csv(csv_path, index=False)
        self.record(csv_path, "table_csv", "tables", name, description)
        tex_path: Path | None = None
        if max_latex_rows > 0 and len(df) <= max_latex_rows:
            tex_path = self.tables_tex / f"{safe_name(name)}.tex"
            with tex_path.open("w", encoding="utf-8") as handle:
                handle.write(dataframe_to_latex(df, longtable=len(df) > 40))
            self.record(tex_path, "table_latex", "tables", name, f"LaTeX version of {description}")
        return csv_path, tex_path

    def save_figure(self, fig: plt.Figure, name: str, dataset: str, description: str) -> None:
        png_path = self.figures_png / f"{safe_name(name)}.png"
        pdf_path = self.figures_pdf / f"{safe_name(name)}.pdf"
        fig.tight_layout()
        fig.savefig(png_path, dpi=180, bbox_inches="tight")
        fig.savefig(pdf_path, bbox_inches="tight")
        plt.close(fig)
        self.record(png_path, "figure_png", dataset, name, description)
        self.record(pdf_path, "figure_pdf", dataset, name, f"PDF version of {description}")

    def write_manifest(self, generated_at: str, notes: list[str]) -> None:
        manifest_df = pd.DataFrame(self.manifest).sort_values(["category", "dataset", "name", "path"])
        csv_path = self.output_dir / "manifest.csv"
        json_path = self.output_dir / "manifest.json"
        md_path = self.output_dir / "manifest.md"
        manifest_df.to_csv(csv_path, index=False)
        json_path.write_text(json.dumps(self.manifest, indent=2), encoding="utf-8")
        lines = [
            "# Comprehensive Final Result Pack",
            "",
            f"Generated at: `{generated_at}`",
            "",
            "This manifest lists generated CSV exports, LaTeX-ready tables, PNG figures, and PDF figures.",
            "",
            "## Notes",
            "",
        ]
        lines.extend(f"- {note}" for note in notes)
        lines.extend(["", "## Files", ""])
        for category, by_category in manifest_df.groupby("category", sort=True):
            lines.extend([f"### {category}", ""])
            for row in by_category.itertuples(index=False):
                lines.append(f"- `{row.path}`: {row.description}")
            lines.append("")
        md_path.write_text("\n".join(lines), encoding="utf-8")


def load_summary(path: Path, result_set: str) -> pd.DataFrame:
    if not path.is_file():
        raise FileNotFoundError(f"Missing summary CSV: {path}")
    df = pd.read_csv(path)
    df["result_set"] = result_set
    df["source_summary_csv"] = str(path)
    return df


def latex_escape(value: object) -> str:
    if pd.isna(value):
        return ""
    if isinstance(value, float):
        if math.isfinite(value):
            text = f"{value:.3f}"
        else:
            text = ""
    else:
        text = str(value)
    replacements = {
        "\\": r"\textbackslash{}",
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
        "{": r"\{",
        "}": r"\}",
        "~": r"\textasciitilde{}",
        "^": r"\textasciicircum{}",
    }
    return "".join(replacements.get(char, char) for char in text)


def dataframe_to_latex(df: pd.DataFrame, longtable: bool = False) -> str:
    column_spec = "l" * len(df.columns)
    env = "longtable" if longtable else "tabular"
    lines = [rf"\begin{{{env}}}{{{column_spec}}}", r"\hline"]
    header = " & ".join(latex_escape(column) for column in df.columns) + r" \\"
    lines.extend([header, r"\hline"])
    for row in df.itertuples(index=False, name=None):
        lines.append(" & ".join(latex_escape(value) for value in row) + r" \\")
    lines.extend([r"\hline", rf"\end{{{env}}}"])
    return "\n".join(lines) + "\n"


def completion_summary() -> pd.DataFrame:
    rows = []
    for name, directory_text in COMPLETION_SETS.items():
        directory = Path(directory_text)
        completed = directory / "completed.jsonl"
        started = directory / "started.jsonl"
        failures = directory / "failures.jsonl"
        rows.append(
            {
                "result_set": name,
                "directory": str(directory),
                "started_rows": count_lines(started),
                "completed_rows": count_lines(completed),
                "failure_rows": count_lines(failures),
                "result_json_files": len(list(directory.glob("*/result.json"))),
                "summary_csv_present": (directory / "summary.csv").is_file(),
                "summary_json_present": (directory / "summary.json").is_file(),
            }
        )
    return pd.DataFrame(rows)


def count_lines(path: Path) -> int:
    if not path.is_file():
        return 0
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        return sum(1 for _ in handle)


def build_matches(df: pd.DataFrame, metrics: list[str]) -> tuple[pd.DataFrame, pd.DataFrame]:
    keys = [field for field in KEY_FIELDS if field in df.columns]
    value_cols = keys + ["security_mode"] + [metric for metric in metrics if metric in df.columns]
    base = df[value_cols].copy()
    full_keys = keys
    counts = base.groupby(full_keys, dropna=False)["security_mode"].nunique().reset_index(name="mode_count")
    full_keys_df = counts[counts["mode_count"] == 3][full_keys]
    matched = base.merge(full_keys_df, on=full_keys, how="inner")

    wide_parts = []
    for mode in SECURITY_ORDER:
        part = matched[matched["security_mode"] == mode][full_keys + metrics].copy()
        part = part.rename(columns={metric: f"{mode}_{metric}" for metric in metrics})
        wide_parts.append(part)
    wide = wide_parts[0]
    for part in wide_parts[1:]:
        wide = wide.merge(part, on=full_keys, how="inner")

    for mode in SECURE_MODES:
        for metric in metrics:
            secure_col = f"{mode}_{metric}"
            plaintext_col = f"plaintext_{metric}"
            if secure_col not in wide.columns or plaintext_col not in wide.columns:
                continue
            wide[f"{mode}_{metric}_pct_change_vs_plaintext"] = pct_change_series(
                wide[secure_col], wide[plaintext_col]
            )
            wide[f"{mode}_{metric}_penalty_pct_vs_plaintext"] = penalty_series(
                wide[secure_col], wide[plaintext_col], metric
            )
            if f"tls_{metric}" in wide.columns and mode == "mtls":
                wide[f"mtls_{metric}_pct_change_vs_tls"] = pct_change_series(
                    wide[f"mtls_{metric}"], wide[f"tls_{metric}"]
                )
    overhead_rows = []
    for _, row in wide.iterrows():
        config = {field: row[field] for field in full_keys}
        for mode in SECURE_MODES:
            for metric in metrics:
                penalty_col = f"{mode}_{metric}_penalty_pct_vs_plaintext"
                change_col = f"{mode}_{metric}_pct_change_vs_plaintext"
                if penalty_col not in wide.columns:
                    continue
                penalty = row[penalty_col]
                change = row[change_col]
                if pd.isna(penalty) and pd.isna(change):
                    continue
                overhead_rows.append(
                    {
                        **config,
                        "comparison_mode": mode,
                        "metric": metric,
                        "metric_label": metric_label(metric),
                        "pct_change_vs_plaintext": change,
                        "penalty_pct_vs_plaintext": penalty,
                    }
                )
    overhead_columns = full_keys + [
        "comparison_mode",
        "metric",
        "metric_label",
        "pct_change_vs_plaintext",
        "penalty_pct_vs_plaintext",
    ]
    overhead = pd.DataFrame(overhead_rows, columns=overhead_columns)
    return wide, overhead


def pct_change_series(candidate: pd.Series, baseline: pd.Series) -> pd.Series:
    baseline_safe = baseline.replace(0, np.nan)
    return ((candidate - baseline_safe) / baseline_safe) * 100.0


def penalty_series(candidate: pd.Series, baseline: pd.Series, metric: str) -> pd.Series:
    baseline_safe = baseline.replace(0, np.nan)
    if metric in HIGHER_IS_BETTER:
        return ((baseline_safe - candidate) / baseline_safe) * 100.0
    return ((candidate - baseline_safe) / baseline_safe) * 100.0


def summary_stats(df: pd.DataFrame, group_cols: list[str], metrics: list[str]) -> pd.DataFrame:
    rows = []
    for metric in metrics:
        if metric not in df.columns or not df[metric].notna().any():
            continue
        grouped = df.groupby(group_cols, dropna=False)[metric]
        for key, values in grouped:
            if not isinstance(key, tuple):
                key = (key,)
            clean = values.dropna()
            if clean.empty:
                continue
            rows.append(
                {
                    **dict(zip(group_cols, key)),
                    "metric": metric,
                    "metric_label": metric_label(metric),
                    "count": int(clean.count()),
                    "mean": clean.mean(),
                    "median": clean.median(),
                    "std": clean.std(ddof=0),
                    "min": clean.min(),
                    "q25": clean.quantile(0.25),
                    "q75": clean.quantile(0.75),
                    "max": clean.max(),
                }
            )
    return pd.DataFrame(rows)


def overhead_summary(overhead: pd.DataFrame, group_cols: list[str]) -> pd.DataFrame:
    if overhead.empty:
        return pd.DataFrame()
    rows = []
    grouped = overhead.groupby(group_cols + ["comparison_mode", "metric"], dropna=False)
    for key, values in grouped:
        clean = values["penalty_pct_vs_plaintext"].dropna()
        if clean.empty:
            continue
        if not isinstance(key, tuple):
            key = (key,)
        row = dict(zip(group_cols + ["comparison_mode", "metric"], key))
        row["metric_label"] = metric_label(row["metric"])
        row.update(
            {
                "count": int(clean.count()),
                "mean_penalty_pct": clean.mean(),
                "median_penalty_pct": clean.median(),
                "std_penalty_pct": clean.std(ddof=0),
                "min_penalty_pct": clean.min(),
                "q25_penalty_pct": clean.quantile(0.25),
                "q75_penalty_pct": clean.quantile(0.75),
                "max_penalty_pct": clean.max(),
            }
        )
        rows.append(row)
    return pd.DataFrame(rows)


def plot_bar_security(exporter: Exporter, df: pd.DataFrame, metric: str, dataset: str) -> None:
    means = (
        df.groupby("security_mode")[metric]
        .mean()
        .reindex(SECURITY_ORDER)
        .dropna()
    )
    if means.empty:
        return
    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.bar(means.index, means.values, color=["#6B7280", "#2563EB", "#DC2626"])
    ax.set_title(f"{dataset}: mean {metric_label(metric)} by security mode")
    ax.set_ylabel(metric_label(metric))
    ax.set_xlabel("Security mode")
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_bar_by_security",
        dataset,
        f"Bar chart of mean {metric_label(metric)} by security mode for {dataset}.",
    )


def plot_grouped_bar(exporter: Exporter, df: pd.DataFrame, metric: str, factor: str, dataset: str) -> None:
    grouped = df.groupby([factor, "security_mode"], dropna=False)[metric].mean().reset_index()
    if grouped.empty:
        return
    factors = sort_factor_values(grouped[factor].unique())
    x = np.arange(len(factors))
    width = 0.25
    fig, ax = plt.subplots(figsize=(max(8, len(factors) * 1.1), 5))
    for index, mode in enumerate(SECURITY_ORDER):
        vals = []
        for value in factors:
            match = grouped[(grouped[factor] == value) & (grouped["security_mode"] == mode)][metric]
            vals.append(match.iloc[0] if not match.empty else np.nan)
        ax.bar(x + (index - 1) * width, vals, width, label=mode)
    ax.set_title(f"{dataset}: mean {metric_label(metric)} by {factor} and security mode")
    ax.set_ylabel(metric_label(metric))
    ax.set_xlabel(factor)
    ax.set_xticks(x)
    ax.set_xticklabels([str(value) for value in factors], rotation=30, ha="right")
    ax.legend()
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_grouped_bar_by_{factor}",
        dataset,
        f"Grouped bar chart of mean {metric_label(metric)} by {factor} and security mode for {dataset}.",
    )


def plot_line_factor(exporter: Exporter, df: pd.DataFrame, metric: str, factor: str, dataset: str) -> None:
    grouped = df.groupby([factor, "security_mode"], dropna=False)[metric].mean().reset_index()
    if grouped.empty:
        return
    factors = sort_factor_values(grouped[factor].unique())
    fig, ax = plt.subplots(figsize=(max(8, len(factors) * 1.1), 5))
    for mode in SECURITY_ORDER:
        vals = []
        for value in factors:
            match = grouped[(grouped[factor] == value) & (grouped["security_mode"] == mode)][metric]
            vals.append(match.iloc[0] if not match.empty else np.nan)
        ax.plot(range(len(factors)), vals, marker="o", label=mode)
    ax.set_title(f"{dataset}: line chart of mean {metric_label(metric)} by {factor}")
    ax.set_ylabel(metric_label(metric))
    ax.set_xlabel(factor)
    ax.set_xticks(range(len(factors)))
    ax.set_xticklabels([str(value) for value in factors], rotation=30, ha="right")
    ax.legend()
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_line_by_{factor}",
        dataset,
        f"Line chart of mean {metric_label(metric)} by {factor} and security mode for {dataset}.",
    )


def plot_box_security(exporter: Exporter, df: pd.DataFrame, metric: str, dataset: str) -> None:
    series = [df[df["security_mode"] == mode][metric].dropna() for mode in SECURITY_ORDER]
    labels = [mode for mode, values in zip(SECURITY_ORDER, series) if not values.empty]
    series = [values for values in series if not values.empty]
    if not series:
        return
    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.boxplot(series, tick_labels=labels, showfliers=True)
    ax.set_title(f"{dataset}: boxplot of {metric_label(metric)} by security mode")
    ax.set_ylabel(metric_label(metric))
    ax.set_xlabel("Security mode")
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_boxplot_by_security",
        dataset,
        f"Boxplot of {metric_label(metric)} by security mode for {dataset}.",
    )


def plot_violin_security(exporter: Exporter, df: pd.DataFrame, metric: str, dataset: str) -> None:
    series = [df[df["security_mode"] == mode][metric].dropna() for mode in SECURITY_ORDER]
    labels = [mode for mode, values in zip(SECURITY_ORDER, series) if len(values) > 1]
    series = [values for values in series if len(values) > 1]
    if not series:
        return
    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.violinplot(series, showmeans=True, showmedians=True)
    ax.set_xticks(range(1, len(labels) + 1))
    ax.set_xticklabels(labels)
    ax.set_title(f"{dataset}: violin plot of {metric_label(metric)} by security mode")
    ax.set_ylabel(metric_label(metric))
    ax.set_xlabel("Security mode")
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_violin_by_security",
        dataset,
        f"Violin plot of {metric_label(metric)} by security mode for {dataset}.",
    )


def plot_hist_security(exporter: Exporter, df: pd.DataFrame, metric: str, dataset: str) -> None:
    fig, ax = plt.subplots(figsize=(8, 5))
    plotted = False
    for mode in SECURITY_ORDER:
        values = df[df["security_mode"] == mode][metric].dropna()
        if values.empty:
            continue
        ax.hist(values, bins=30, alpha=0.45, label=mode)
        plotted = True
    if not plotted:
        plt.close(fig)
        return
    ax.set_title(f"{dataset}: histogram of {metric_label(metric)} by security mode")
    ax.set_xlabel(metric_label(metric))
    ax.set_ylabel("Count")
    ax.legend()
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_histogram_by_security",
        dataset,
        f"Histogram of {metric_label(metric)} by security mode for {dataset}.",
    )


def plot_scatter_factor(exporter: Exporter, df: pd.DataFrame, metric: str, factor: str, dataset: str) -> None:
    if factor not in df.columns:
        return
    factor_numeric = pd.to_numeric(df[factor], errors="coerce")
    if factor_numeric.notna().sum() == 0:
        return
    fig, ax = plt.subplots(figsize=(8, 5))
    colors = {"plaintext": "#6B7280", "tls": "#2563EB", "mtls": "#DC2626"}
    plotted = False
    for mode in SECURITY_ORDER:
        mask = df["security_mode"] == mode
        x = factor_numeric[mask]
        y = df.loc[mask, metric]
        good = x.notna() & y.notna()
        if good.any():
            ax.scatter(x[good], y[good], alpha=0.45, s=18, label=mode, color=colors[mode])
            plotted = True
    if not plotted:
        plt.close(fig)
        return
    ax.set_title(f"{dataset}: scatter of {metric_label(metric)} vs {factor}")
    ax.set_xlabel(factor)
    ax.set_ylabel(metric_label(metric))
    ax.legend()
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_scatter_vs_{factor}",
        dataset,
        f"Scatter plot of {metric_label(metric)} against {factor} by security mode for {dataset}.",
    )


def plot_heatmap_factor_security(exporter: Exporter, df: pd.DataFrame, metric: str, factor: str, dataset: str) -> None:
    pivot = df.pivot_table(index=factor, columns="security_mode", values=metric, aggfunc="mean")
    pivot = pivot.reindex(columns=[mode for mode in SECURITY_ORDER if mode in pivot.columns])
    if pivot.empty:
        return
    pivot = pivot.loc[sort_factor_values(pivot.index)]
    data = pivot.to_numpy(dtype=float)
    fig, ax = plt.subplots(figsize=(max(6, len(pivot.columns) * 1.2), max(4, len(pivot.index) * 0.45)))
    image = ax.imshow(data, aspect="auto", cmap="viridis")
    ax.set_xticks(range(len(pivot.columns)))
    ax.set_xticklabels(pivot.columns)
    ax.set_yticks(range(len(pivot.index)))
    ax.set_yticklabels([str(value) for value in pivot.index])
    ax.set_title(f"{dataset}: heatmap of mean {metric_label(metric)} by {factor}")
    ax.set_xlabel("Security mode")
    ax.set_ylabel(factor)
    fig.colorbar(image, ax=ax, label=metric_label(metric))
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_heatmap_by_{factor}_security",
        dataset,
        f"Heatmap of mean {metric_label(metric)} by {factor} and security mode for {dataset}.",
    )


def plot_overhead_bar(exporter: Exporter, overhead: pd.DataFrame, metric: str, dataset: str) -> None:
    subset = overhead[overhead["metric"] == metric]
    if subset.empty:
        return
    means = subset.groupby("comparison_mode")["penalty_pct_vs_plaintext"].mean().reindex(SECURE_MODES).dropna()
    if means.empty:
        return
    fig, ax = plt.subplots(figsize=(6, 4.5))
    ax.bar(means.index, means.values, color=["#2563EB", "#DC2626"])
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_title(f"{dataset}: mean penalty for {metric_label(metric)} vs plaintext")
    ax.set_ylabel("Penalty % vs plaintext")
    ax.set_xlabel("Comparison mode")
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_overhead_bar_vs_plaintext",
        dataset,
        f"Bar chart of mean penalty percentage for {metric_label(metric)} relative to plaintext for {dataset}.",
    )


def plot_overhead_box(exporter: Exporter, overhead: pd.DataFrame, metric: str, dataset: str) -> None:
    subset = overhead[overhead["metric"] == metric]
    series = [subset[subset["comparison_mode"] == mode]["penalty_pct_vs_plaintext"].dropna() for mode in SECURE_MODES]
    labels = [mode for mode, values in zip(SECURE_MODES, series) if not values.empty]
    series = [values for values in series if not values.empty]
    if not series:
        return
    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.boxplot(series, tick_labels=labels, showfliers=True)
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_title(f"{dataset}: penalty distribution for {metric_label(metric)}")
    ax.set_ylabel("Penalty % vs plaintext")
    ax.set_xlabel("Comparison mode")
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_overhead_boxplot_vs_plaintext",
        dataset,
        f"Boxplot of penalty percentage for {metric_label(metric)} relative to plaintext for {dataset}.",
    )


def plot_overhead_hist(exporter: Exporter, overhead: pd.DataFrame, metric: str, dataset: str) -> None:
    subset = overhead[overhead["metric"] == metric]
    fig, ax = plt.subplots(figsize=(8, 5))
    plotted = False
    for mode in SECURE_MODES:
        values = subset[subset["comparison_mode"] == mode]["penalty_pct_vs_plaintext"].dropna()
        if values.empty:
            continue
        ax.hist(values, bins=30, alpha=0.45, label=mode)
        plotted = True
    if not plotted:
        plt.close(fig)
        return
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_title(f"{dataset}: penalty histogram for {metric_label(metric)}")
    ax.set_xlabel("Penalty % vs plaintext")
    ax.set_ylabel("Count")
    ax.legend()
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_overhead_histogram_vs_plaintext",
        dataset,
        f"Histogram of penalty percentage for {metric_label(metric)} relative to plaintext for {dataset}.",
    )


def plot_overhead_factor(exporter: Exporter, overhead: pd.DataFrame, metric: str, factor: str, dataset: str, kind: str) -> None:
    subset = overhead[overhead["metric"] == metric].copy()
    if subset.empty or factor not in subset.columns:
        return
    grouped = subset.groupby([factor, "comparison_mode"], dropna=False)["penalty_pct_vs_plaintext"].mean().reset_index()
    if grouped.empty:
        return
    factors = sort_factor_values(grouped[factor].unique())
    if kind == "line":
        fig, ax = plt.subplots(figsize=(max(8, len(factors) * 1.1), 5))
        for mode in SECURE_MODES:
            vals = []
            for value in factors:
                match = grouped[(grouped[factor] == value) & (grouped["comparison_mode"] == mode)]["penalty_pct_vs_plaintext"]
                vals.append(match.iloc[0] if not match.empty else np.nan)
            ax.plot(range(len(factors)), vals, marker="o", label=mode)
        ax.set_xticks(range(len(factors)))
        ax.set_xticklabels([str(value) for value in factors], rotation=30, ha="right")
    elif kind == "bar":
        x = np.arange(len(factors))
        width = 0.35
        fig, ax = plt.subplots(figsize=(max(8, len(factors) * 1.1), 5))
        for index, mode in enumerate(SECURE_MODES):
            vals = []
            for value in factors:
                match = grouped[(grouped[factor] == value) & (grouped["comparison_mode"] == mode)]["penalty_pct_vs_plaintext"]
                vals.append(match.iloc[0] if not match.empty else np.nan)
            ax.bar(x + (index - 0.5) * width, vals, width, label=mode)
        ax.set_xticks(x)
        ax.set_xticklabels([str(value) for value in factors], rotation=30, ha="right")
    else:
        return
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_title(f"{dataset}: {kind} penalty for {metric_label(metric)} by {factor}")
    ax.set_xlabel(factor)
    ax.set_ylabel("Penalty % vs plaintext")
    ax.legend()
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_overhead_{kind}_by_{factor}",
        dataset,
        f"{kind.title()} chart of penalty percentage for {metric_label(metric)} by {factor} relative to plaintext for {dataset}.",
    )


def plot_overhead_scatter(exporter: Exporter, overhead: pd.DataFrame, metric: str, factor: str, dataset: str) -> None:
    subset = overhead[overhead["metric"] == metric].copy()
    if subset.empty or factor not in subset.columns:
        return
    x_numeric = pd.to_numeric(subset[factor], errors="coerce")
    if x_numeric.notna().sum() == 0:
        return
    fig, ax = plt.subplots(figsize=(8, 5))
    colors = {"tls": "#2563EB", "mtls": "#DC2626"}
    plotted = False
    for mode in SECURE_MODES:
        mask = subset["comparison_mode"] == mode
        good = x_numeric[mask].notna() & subset.loc[mask, "penalty_pct_vs_plaintext"].notna()
        if good.any():
            ax.scatter(
                x_numeric[mask][good],
                subset.loc[mask, "penalty_pct_vs_plaintext"][good],
                alpha=0.45,
                s=18,
                label=mode,
                color=colors[mode],
            )
            plotted = True
    if not plotted:
        plt.close(fig)
        return
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_title(f"{dataset}: scatter penalty for {metric_label(metric)} vs {factor}")
    ax.set_xlabel(factor)
    ax.set_ylabel("Penalty % vs plaintext")
    ax.legend()
    exporter.save_figure(
        fig,
        f"{dataset}_{metric}_overhead_scatter_vs_{factor}",
        dataset,
        f"Scatter plot of penalty percentage for {metric_label(metric)} against {factor} relative to plaintext for {dataset}.",
    )


def plot_metric_correlation_heatmap(exporter: Exporter, df: pd.DataFrame, metrics: list[str], dataset: str) -> None:
    present = [metric for metric in metrics if metric in df.columns and df[metric].notna().any()]
    if len(present) < 2:
        return
    corr = df[present].corr(numeric_only=True)
    if corr.empty:
        return
    fig, ax = plt.subplots(figsize=(max(10, len(present) * 0.35), max(8, len(present) * 0.35)))
    image = ax.imshow(corr.to_numpy(), cmap="coolwarm", vmin=-1, vmax=1)
    ax.set_xticks(range(len(present)))
    ax.set_xticklabels([metric_label(metric) for metric in present], rotation=60, ha="right", fontsize=7)
    ax.set_yticks(range(len(present)))
    ax.set_yticklabels([metric_label(metric) for metric in present], fontsize=7)
    ax.set_title(f"{dataset}: metric correlation heatmap")
    fig.colorbar(image, ax=ax, label="Pearson correlation")
    exporter.save_figure(
        fig,
        f"{dataset}_metric_correlation_heatmap",
        dataset,
        f"Correlation heatmap across available numeric metrics for {dataset}.",
    )


def generate_dataset_outputs(
    exporter: Exporter,
    dataset: str,
    df: pd.DataFrame,
    metrics: list[str],
    factors: list[str],
    matched: pd.DataFrame,
    overhead: pd.DataFrame,
) -> None:
    metrics = available_metrics(df, metrics)
    factors = [factor for factor in factors if factor in df.columns and df[factor].notna().any()]

    exporter.write_table(
        f"{dataset}_absolute_summary_by_security",
        summary_stats(df, ["security_mode"], metrics),
        f"Absolute metric summary by security mode for {dataset}.",
    )
    if "broker_count" in df.columns:
        exporter.write_table(
            f"{dataset}_absolute_summary_by_broker_and_security",
            summary_stats(df, ["broker_count", "security_mode"], metrics),
            f"Absolute metric summary by broker count and security mode for {dataset}.",
        )
    exporter.write_table(
        f"{dataset}_overhead_summary_by_metric",
        overhead_summary(overhead, []),
        f"Penalty percentage summary by metric and comparison mode for {dataset}.",
    )
    if "broker_count" in overhead.columns:
        exporter.write_table(
            f"{dataset}_overhead_summary_by_broker_and_metric",
            overhead_summary(overhead, ["broker_count"]),
            f"Penalty percentage summary by broker count, metric, and comparison mode for {dataset}.",
        )

    for factor in factors:
        exporter.write_table(
            f"{dataset}_absolute_summary_by_{factor}",
            summary_stats(df, [factor, "security_mode"], metrics),
            f"Absolute metric summary by {factor} and security mode for {dataset}.",
            max_latex_rows=250,
        )
        if factor in overhead.columns:
            exporter.write_table(
                f"{dataset}_overhead_summary_by_{factor}",
                overhead_summary(overhead, [factor]),
                f"Penalty percentage summary by {factor}, metric, and comparison mode for {dataset}.",
                max_latex_rows=250,
            )

    top_rows = []
    for metric in metrics:
        subset = overhead[overhead["metric"] == metric]
        for mode in SECURE_MODES:
            mode_subset = subset[subset["comparison_mode"] == mode].dropna(subset=["penalty_pct_vs_plaintext"])
            if mode_subset.empty:
                continue
            top_rows.extend(mode_subset.nlargest(10, "penalty_pct_vs_plaintext").assign(rank_type="highest_penalty").to_dict("records"))
            top_rows.extend(mode_subset.nsmallest(10, "penalty_pct_vs_plaintext").assign(rank_type="lowest_penalty").to_dict("records"))
    if top_rows:
        exporter.write_table(
            f"{dataset}_top_overhead_cases",
            pd.DataFrame(top_rows),
            f"Top and bottom penalty cases by metric and comparison mode for {dataset}.",
            max_latex_rows=0,
        )

    for metric in metrics:
        plot_bar_security(exporter, df, metric, dataset)
        plot_box_security(exporter, df, metric, dataset)
        plot_violin_security(exporter, df, metric, dataset)
        plot_hist_security(exporter, df, metric, dataset)
        plot_overhead_bar(exporter, overhead, metric, dataset)
        plot_overhead_box(exporter, overhead, metric, dataset)
        plot_overhead_hist(exporter, overhead, metric, dataset)
        for factor in factors:
            plot_grouped_bar(exporter, df, metric, factor, dataset)
            plot_line_factor(exporter, df, metric, factor, dataset)
            plot_scatter_factor(exporter, df, metric, factor, dataset)
            plot_heatmap_factor_security(exporter, df, metric, factor, dataset)
            plot_overhead_factor(exporter, overhead, metric, factor, dataset, "line")
            plot_overhead_factor(exporter, overhead, metric, factor, dataset, "bar")
            plot_overhead_scatter(exporter, overhead, metric, factor, dataset)

    plot_metric_correlation_heatmap(exporter, df, metrics, dataset)


def generate_chapter4_tables(exporter: Exporter, producer: pd.DataFrame, consumer: pd.DataFrame, producer_matched: pd.DataFrame, producer_overhead: pd.DataFrame, consumer_matched: pd.DataFrame, consumer_overhead: pd.DataFrame) -> None:
    completion = completion_summary()
    completion["planned_rows"] = completion["result_set"].map(planned_rows_for_result_set)
    completion["matched_rows"] = completion["result_set"].map(
        matched_rows_for_result_set(producer_matched, consumer_matched)
    )
    exporter.write_table(
        "chapter4_completion_summary",
        completion[
            [
                "result_set",
                "planned_rows",
                "started_rows",
                "completed_rows",
                "failure_rows",
                "result_json_files",
                "matched_rows",
            ]
        ],
        "Chapter 4 completion and matched-analysis summary.",
    )

    core_metrics = [
        "throughput_records_per_sec",
        "throughput_mb_per_sec",
        "avg_latency_ms",
        "max_latency_ms",
        "benchmark_client_cpu_percent_mean",
        "broker_cpu_percent_mean",
        "broker_cpu_percent_max_mean",
    ]
    producer_core = summary_stats(producer, ["security_mode"], [m for m in core_metrics if m in producer.columns])
    exporter.write_table(
        "chapter4_producer_core_absolute_summary",
        producer_core,
        "Chapter 4 core producer absolute metric summary.",
    )
    producer_core_overhead = overhead_summary(
        producer_overhead[producer_overhead["metric"].isin(core_metrics)],
        [],
    )
    exporter.write_table(
        "chapter4_producer_core_overhead_summary",
        producer_core_overhead,
        "Chapter 4 core producer penalty summary relative to plaintext.",
    )
    consumer_core = summary_stats(
        consumer,
        ["security_mode"],
        [metric for metric in ["throughput_records_per_sec", "throughput_mb_per_sec", "data_consumed_mb", "fetch_time_ms", "benchmark_client_cpu_percent_mean", "broker_cpu_percent_mean"] if metric in consumer.columns],
    )
    exporter.write_table(
        "chapter4_consumer_core_absolute_summary",
        consumer_core,
        "Chapter 4 targeted consumer validation absolute metric summary.",
    )
    consumer_core_overhead = overhead_summary(
        consumer_overhead[
            consumer_overhead["metric"].isin(
                [
                    "throughput_records_per_sec",
                    "throughput_mb_per_sec",
                    "data_consumed_mb",
                    "fetch_time_ms",
                    "benchmark_client_cpu_percent_mean",
                    "broker_cpu_percent_mean",
                ]
            )
        ],
        [],
    )
    exporter.write_table(
        "chapter4_consumer_core_overhead_summary",
        consumer_core_overhead,
        "Chapter 4 targeted consumer validation penalty summary relative to plaintext.",
    )


def planned_rows_for_result_set(result_set: str) -> int | None:
    if "consumer" in result_set:
        return 24
    if "broker5" in result_set:
        return 1296
    if "broker3" in result_set:
        return 432
    return None


def matched_rows_for_result_set(producer_matched: pd.DataFrame, consumer_matched: pd.DataFrame) -> dict[str, int]:
    counts: dict[str, int] = {}
    if not producer_matched.empty:
        for broker_count, count in producer_matched.groupby("broker_count").size().items():
            per_mode = int(count)
            if int(broker_count) == 5:
                for mode in SECURITY_ORDER:
                    counts[f"{mode}_broker5"] = per_mode
            elif int(broker_count) == 3:
                for mode in SECURITY_ORDER:
                    counts[f"{mode}_broker3"] = per_mode
    if not consumer_matched.empty:
        for mode in SECURITY_ORDER:
            counts[f"consumer_{mode}_broker5"] = len(consumer_matched)
    return counts


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate comprehensive final result tables and figures.")
    parser.add_argument(
        "--output-dir",
        default="",
        help="Output directory. Defaults to results/final-processed/comprehensive-result-pack-<UTC timestamp>.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    generated_at = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output_dir = Path(args.output_dir) if args.output_dir else Path("results/final-processed") / f"comprehensive-result-pack-{generated_at}"
    exporter = Exporter(output_dir)

    producer = pd.concat(
        [load_summary(Path(path), name) for name, path in PRODUCER_RESULT_SETS.items()],
        ignore_index=True,
    )
    consumer = pd.concat(
        [load_summary(Path(path), name) for name, path in CONSUMER_RESULT_SETS.items()],
        ignore_index=True,
    )
    all_numeric = sorted(set(PRODUCER_METRICS + CONSUMER_METRICS + NUMERIC_KEY_FIELDS + ["records_sent", "records_consumed"]))
    producer = ensure_numeric(producer, all_numeric)
    consumer = ensure_numeric(consumer, all_numeric)
    producer["dataset"] = "producer"
    consumer["dataset"] = "consumer"

    producer_metrics = available_metrics(producer, PRODUCER_METRICS)
    consumer_metrics = available_metrics(consumer, CONSUMER_METRICS)
    producer_matched, producer_overhead = build_matches(producer, producer_metrics)
    consumer_matched, consumer_overhead = build_matches(consumer, consumer_metrics)

    exporter.write_data("producer_combined_rows", producer, "Combined producer summary rows from all final security-mode and broker-count phases.")
    exporter.write_data("consumer_combined_rows", consumer, "Combined consumer validation summary rows from all security modes.")
    exporter.write_data("producer_matched_wide_comparison", producer_matched, "Wide matched producer comparison rows with plaintext, TLS, mTLS, percent change, and penalty columns.")
    exporter.write_data("producer_overhead_long", producer_overhead, "Long-form producer penalty and percent-change rows by metric and comparison mode.")
    exporter.write_data("consumer_matched_wide_comparison", consumer_matched, "Wide matched consumer comparison rows with plaintext, TLS, mTLS, percent change, and penalty columns.")
    exporter.write_data("consumer_overhead_long", consumer_overhead, "Long-form consumer penalty and percent-change rows by metric and comparison mode.")
    exporter.write_data("all_combined_rows", pd.concat([producer, consumer], ignore_index=True, sort=False), "Combined producer and consumer summary rows.")

    generate_chapter4_tables(
        exporter,
        producer,
        consumer,
        producer_matched,
        producer_overhead,
        consumer_matched,
        consumer_overhead,
    )
    generate_dataset_outputs(
        exporter,
        "producer",
        producer,
        producer_metrics,
        PRODUCER_FACTORS,
        producer_matched,
        producer_overhead,
    )
    generate_dataset_outputs(
        exporter,
        "consumer",
        consumer,
        consumer_metrics,
        CONSUMER_FACTORS,
        consumer_matched,
        consumer_overhead,
    )

    notes = [
        "Positive penalty percentage means worse than the matched plaintext baseline. For throughput metrics this means lower throughput; for latency and resource metrics this means higher values.",
        "Raw percent-change columns are also exported in the wide matched comparison CSVs so direction can be inspected directly.",
        "Producer matched rows require plaintext, TLS, and mTLS to share the same workload, deployment, and trial fields.",
        "Consumer outputs are based on the targeted validation slice and should be reported separately from the producer factorial campaign.",
        "Figures are intentionally broad and include chart types that may not all be dissertation-final candidates.",
    ]
    exporter.write_manifest(generated_at, notes)
    print(f"Wrote comprehensive result pack to {output_dir}")
    print(f"Files generated: {len(exporter.manifest) + 3}")


if __name__ == "__main__":
    main()
