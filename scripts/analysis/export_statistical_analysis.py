#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd


SECURE_MODES = ["tls", "mtls"]

METRIC_LABELS = {
    "throughput_records_per_sec": "Throughput records/s",
    "throughput_mb_per_sec": "Throughput MB/s",
    "avg_latency_ms": "Average latency ms",
    "max_latency_ms": "Maximum latency ms",
    "fetch_time_ms": "Consumer fetch time ms",
    "benchmark_client_cpu_percent_mean": "Benchmark client CPU %",
    "broker_cpu_percent_mean": "Broker CPU mean %",
}

PRODUCER_KEY_METRICS = [
    "throughput_records_per_sec",
    "avg_latency_ms",
    "max_latency_ms",
    "benchmark_client_cpu_percent_mean",
    "broker_cpu_percent_mean",
]

CONSUMER_KEY_METRICS = [
    "throughput_records_per_sec",
    "fetch_time_ms",
    "benchmark_client_cpu_percent_mean",
    "broker_cpu_percent_mean",
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export statistical summaries for matched Kafka security-overhead results.",
    )
    parser.add_argument(
        "--pack-dir",
        type=Path,
        default=Path("results/final-processed/comprehensive-result-pack"),
        help="Comprehensive result-pack directory.",
    )
    parser.add_argument(
        "--bootstrap-samples",
        type=int,
        default=5000,
        help="Number of bootstrap resamples for confidence intervals.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=20260430,
        help="Random seed for reproducible bootstrap intervals.",
    )
    return parser.parse_args()


def metric_label(metric: str) -> str:
    return METRIC_LABELS.get(metric, metric.replace("_", " "))


def clean_values(values: pd.Series) -> np.ndarray:
    return pd.to_numeric(values, errors="coerce").replace([np.inf, -np.inf], np.nan).dropna().to_numpy(float)


def bootstrap_interval(values: np.ndarray, samples: int, seed: int) -> dict[str, float]:
    if values.size == 0:
        return {
            "mean_ci_low_pct": math.nan,
            "mean_ci_high_pct": math.nan,
            "median_ci_low_pct": math.nan,
            "median_ci_high_pct": math.nan,
        }

    rng = np.random.default_rng(seed)
    sample_indexes = rng.integers(0, values.size, size=(samples, values.size))
    boot = values[sample_indexes]
    boot_means = np.mean(boot, axis=1)
    boot_medians = np.median(boot, axis=1)

    return {
        "mean_ci_low_pct": float(np.percentile(boot_means, 2.5)),
        "mean_ci_high_pct": float(np.percentile(boot_means, 97.5)),
        "median_ci_low_pct": float(np.percentile(boot_medians, 2.5)),
        "median_ci_high_pct": float(np.percentile(boot_medians, 97.5)),
    }


def sign_test_normal_approx(positive: int, negative: int) -> tuple[float, float]:
    n = positive + negative
    if n == 0:
        return math.nan, math.nan

    mean = n / 2
    std = math.sqrt(n / 4)
    # Continuity correction around the expected half-positive split.
    z = (abs(positive - mean) - 0.5) / std
    z = max(z, 0.0)
    p_value = math.erfc(z / math.sqrt(2))
    signed_z = math.copysign(z, positive - negative)
    return signed_z, p_value


def format_float(value: object, digits: int = 3) -> str:
    if value is None:
        return ""
    try:
        value_float = float(value)
    except (TypeError, ValueError):
        return str(value)
    if math.isnan(value_float):
        return ""
    return f"{value_float:.{digits}f}"


def format_p_value(value: object) -> str:
    try:
        value_float = float(value)
    except (TypeError, ValueError):
        return str(value)
    if math.isnan(value_float):
        return ""
    if value_float < 0.001:
        return "<0.001"
    return f"{value_float:.3f}"


def format_level(value: object) -> str:
    if pd.isna(value):
        return ""
    if isinstance(value, (int, np.integer)):
        return str(int(value))
    if isinstance(value, (float, np.floating)) and float(value).is_integer():
        return str(int(value))
    return str(value)


def latex_escape(value: object) -> str:
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
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def write_latex_table(
    df: pd.DataFrame,
    path: Path,
    caption: str,
    label: str,
    float_columns: Iterable[str] = (),
    p_value_columns: Iterable[str] = (),
    column_spec: str | None = None,
) -> None:
    float_columns = set(float_columns)
    p_value_columns = set(p_value_columns)
    if column_spec is None:
        column_spec = "|" + "|".join(["l"] * len(df.columns)) + "|"

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\setlength{\tabcolsep}{4pt}",
        r"\renewcommand{\arraystretch}{1.15}",
        rf"\begin{{tabular}}{{{column_spec}}}",
        r"\hline",
        " & ".join(rf"\textbf{{{latex_escape(column)}}}" for column in df.columns) + r" \\",
        r"\hline",
    ]

    for _, row in df.iterrows():
        rendered = []
        for column in df.columns:
            value = row[column]
            if column in p_value_columns:
                rendered.append(latex_escape(format_p_value(value)))
            elif column in float_columns:
                rendered.append(latex_escape(format_float(value)))
            else:
                rendered.append(latex_escape(value))
        lines.append(" & ".join(rendered) + r" \\")

    lines.extend(
        [
            r"\hline",
            r"\end{tabular}",
            rf"\caption{{{latex_escape(caption)}}}",
            rf"\label{{{label}}}",
            r"\end{table}",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def interval_text(low: object, high: object) -> str:
    return f"[{format_float(low)}, {format_float(high)}]"


def compact_ci_table(df: pd.DataFrame) -> pd.DataFrame:
    return pd.DataFrame(
        {
            "Mode": df["comparison_mode"],
            "Metric": df["metric_label"],
            "n": df["count"],
            "Mean penalty": df["mean_penalty_pct"].map(lambda value: f"{format_float(value)}%"),
            "Mean 95% CI": [
                interval_text(low, high)
                for low, high in zip(df["mean_ci_low_pct"], df["mean_ci_high_pct"], strict=False)
            ],
            "Median penalty": df["median_penalty_pct"].map(lambda value: f"{format_float(value)}%"),
            "Median 95% CI": [
                interval_text(low, high)
                for low, high in zip(df["median_ci_low_pct"], df["median_ci_high_pct"], strict=False)
            ],
        }
    )


def compact_effect_table(df: pd.DataFrame) -> pd.DataFrame:
    return pd.DataFrame(
        {
            "Mode": df["comparison_mode"],
            "Metric": df["metric_label"],
            "n": df["count"],
            "Worse rows": df["pct_rows_worse"].map(lambda value: f"{format_float(value)}%"),
            "Mean penalty": df["mean_penalty_pct"].map(lambda value: f"{format_float(value)}%"),
            "Effect dz": df["paired_effect_dz"].map(format_float),
            "Sign-test p": df["sign_test_p_approx"].map(format_p_value),
        }
    )


def compact_factor_table(df: pd.DataFrame) -> pd.DataFrame:
    return pd.DataFrame(
        {
            "Dataset": df["benchmark_type"],
            "Mode": df["comparison_mode"],
            "Metric": df["metric_label"],
            "Factor": df["factor"],
            "Lowest level": df["lowest_mean_penalty_level"],
            "Highest level": df["highest_mean_penalty_level"],
            "Spread": df["mean_penalty_spread_pct"].map(lambda value: f"{format_float(value)}%"),
        }
    )


def confidence_rows(
    matched_df: pd.DataFrame,
    benchmark_type: str,
    metrics: list[str],
    bootstrap_samples: int,
    seed: int,
) -> pd.DataFrame:
    rows: list[dict[str, object]] = []

    for mode_index, mode in enumerate(SECURE_MODES):
        for metric_index, metric in enumerate(metrics):
            column = f"{mode}_{metric}_penalty_pct_vs_plaintext"
            if column not in matched_df:
                continue
            values = clean_values(matched_df[column])
            interval = bootstrap_interval(values, bootstrap_samples, seed + (mode_index * 100) + metric_index)
            rows.append(
                {
                    "benchmark_type": benchmark_type,
                    "comparison_mode": mode,
                    "metric": metric,
                    "metric_label": metric_label(metric),
                    "count": int(values.size),
                    "mean_penalty_pct": float(np.mean(values)) if values.size else math.nan,
                    "median_penalty_pct": float(np.median(values)) if values.size else math.nan,
                    **interval,
                }
            )

    return pd.DataFrame(rows)


def paired_effect_rows(matched_df: pd.DataFrame, benchmark_type: str, metrics: list[str]) -> pd.DataFrame:
    rows: list[dict[str, object]] = []

    for mode in SECURE_MODES:
        for metric in metrics:
            column = f"{mode}_{metric}_penalty_pct_vs_plaintext"
            if column not in matched_df:
                continue
            values = clean_values(matched_df[column])
            if values.size == 0:
                continue

            positive = int(np.sum(values > 0))
            negative = int(np.sum(values < 0))
            zero = int(np.sum(values == 0))
            signed_z, p_value = sign_test_normal_approx(positive, negative)
            std = float(np.std(values, ddof=1)) if values.size > 1 else math.nan
            effect = float(np.mean(values) / std) if std and not math.isnan(std) else math.nan

            rows.append(
                {
                    "benchmark_type": benchmark_type,
                    "comparison_mode": mode,
                    "metric": metric,
                    "metric_label": metric_label(metric),
                    "count": int(values.size),
                    "rows_worse": positive,
                    "rows_better": negative,
                    "rows_equal": zero,
                    "pct_rows_worse": float((positive / values.size) * 100),
                    "mean_penalty_pct": float(np.mean(values)),
                    "median_penalty_pct": float(np.median(values)),
                    "paired_effect_dz": effect,
                    "sign_test_z": signed_z,
                    "sign_test_p_approx": p_value,
                }
            )

    return pd.DataFrame(rows)


def factor_sensitivity_rows(
    overhead_df: pd.DataFrame,
    benchmark_type: str,
    metrics: list[str],
    factors: list[str],
) -> pd.DataFrame:
    rows: list[dict[str, object]] = []

    for mode in SECURE_MODES:
        mode_df = overhead_df[overhead_df["comparison_mode"].eq(mode)]
        for metric in metrics:
            metric_df = mode_df[mode_df["metric"].eq(metric)].copy()
            if metric_df.empty:
                continue
            metric_df["penalty_pct_vs_plaintext"] = pd.to_numeric(
                metric_df["penalty_pct_vs_plaintext"],
                errors="coerce",
            )
            metric_df = metric_df.dropna(subset=["penalty_pct_vs_plaintext"])

            for factor in factors:
                if factor not in metric_df:
                    continue

                grouped = (
                    metric_df.groupby(factor, dropna=False)["penalty_pct_vs_plaintext"]
                    .mean()
                    .reset_index()
                    .sort_values("penalty_pct_vs_plaintext")
                )
                level_count = int(grouped[factor].nunique(dropna=False))
                if grouped.empty or level_count < 2:
                    continue

                min_row = grouped.iloc[0]
                max_row = grouped.iloc[-1]
                spread = float(max_row["penalty_pct_vs_plaintext"] - min_row["penalty_pct_vs_plaintext"])

                rows.append(
                    {
                        "benchmark_type": benchmark_type,
                        "comparison_mode": mode,
                        "metric": metric,
                        "metric_label": metric_label(metric),
                        "factor": factor,
                        "level_count": level_count,
                        "lowest_mean_penalty_level": format_level(min_row[factor]),
                        "lowest_mean_penalty_pct": float(min_row["penalty_pct_vs_plaintext"]),
                        "highest_mean_penalty_level": format_level(max_row[factor]),
                        "highest_mean_penalty_pct": float(max_row["penalty_pct_vs_plaintext"]),
                        "mean_penalty_spread_pct": spread,
                    }
                )

    return pd.DataFrame(rows)


def top_factor_rows(factor_df: pd.DataFrame, top_n: int = 2) -> pd.DataFrame:
    if factor_df.empty:
        return factor_df

    return (
        factor_df.assign(abs_mean_penalty_spread_pct=factor_df["mean_penalty_spread_pct"].abs())
        .sort_values(
            [
                "benchmark_type",
                "comparison_mode",
                "metric",
                "abs_mean_penalty_spread_pct",
            ],
            ascending=[True, True, True, False],
        )
        .groupby(["benchmark_type", "comparison_mode", "metric"], as_index=False)
        .head(top_n)
        .drop(columns=["abs_mean_penalty_spread_pct"])
        .reset_index(drop=True)
    )


def write_outputs(pack_dir: Path, name: str, df: pd.DataFrame) -> None:
    csv_dir = pack_dir / "statistics" / "csv"
    csv_dir.mkdir(parents=True, exist_ok=True)
    df.to_csv(csv_dir / f"{name}.csv", index=False)


def main() -> None:
    args = parse_args()
    pack_dir: Path = args.pack_dir
    statistics_dir = pack_dir / "statistics"
    csv_dir = statistics_dir / "csv"
    latex_dir = statistics_dir / "latex"
    csv_dir.mkdir(parents=True, exist_ok=True)
    latex_dir.mkdir(parents=True, exist_ok=True)

    producer_wide = pd.read_csv(pack_dir / "data" / "producer_matched_wide_comparison.csv")
    consumer_wide = pd.read_csv(pack_dir / "data" / "consumer_matched_wide_comparison.csv")
    producer_overhead = pd.read_csv(pack_dir / "data" / "producer_overhead_long.csv")
    consumer_overhead = pd.read_csv(pack_dir / "data" / "consumer_overhead_long.csv")

    producer_ci = confidence_rows(
        producer_wide,
        "producer",
        PRODUCER_KEY_METRICS,
        args.bootstrap_samples,
        args.seed,
    )
    consumer_ci = confidence_rows(
        consumer_wide,
        "consumer",
        CONSUMER_KEY_METRICS,
        args.bootstrap_samples,
        args.seed + 1000,
    )
    producer_effects = paired_effect_rows(producer_wide, "producer", PRODUCER_KEY_METRICS)
    consumer_effects = paired_effect_rows(consumer_wide, "consumer", CONSUMER_KEY_METRICS)
    producer_factors = factor_sensitivity_rows(
        producer_overhead,
        "producer",
        ["throughput_records_per_sec", "avg_latency_ms"],
        PRODUCER_FACTORS,
    )
    consumer_factors = factor_sensitivity_rows(
        consumer_overhead,
        "consumer",
        ["throughput_records_per_sec", "fetch_time_ms"],
        CONSUMER_FACTORS,
    )
    factor_top = top_factor_rows(pd.concat([producer_factors, consumer_factors], ignore_index=True), top_n=2)

    outputs = {
        "producer_bootstrap_ci": producer_ci,
        "consumer_bootstrap_ci": consumer_ci,
        "producer_paired_effects": producer_effects,
        "consumer_paired_effects": consumer_effects,
        "factor_sensitivity_full": pd.concat([producer_factors, consumer_factors], ignore_index=True),
        "factor_sensitivity_top": factor_top,
    }

    for name, df in outputs.items():
        df.to_csv(csv_dir / f"{name}.csv", index=False)

    float_ci = [
        "mean_penalty_pct",
        "median_penalty_pct",
        "mean_ci_low_pct",
        "mean_ci_high_pct",
        "median_ci_low_pct",
        "median_ci_high_pct",
    ]
    float_effects = [
        "pct_rows_worse",
        "mean_penalty_pct",
        "median_penalty_pct",
        "paired_effect_dz",
        "sign_test_z",
    ]
    float_factors = [
        "lowest_mean_penalty_pct",
        "highest_mean_penalty_pct",
        "mean_penalty_spread_pct",
    ]

    write_latex_table(
        compact_ci_table(producer_ci),
        latex_dir / "producer_bootstrap_ci.tex",
        "Bootstrap confidence intervals for key producer penalties",
        "tab:producer-bootstrap-ci",
        column_spec="|p{0.10\\linewidth}|p{0.20\\linewidth}|r|r|p{0.14\\linewidth}|r|p{0.14\\linewidth}|",
    )
    write_latex_table(
        compact_ci_table(consumer_ci),
        latex_dir / "consumer_bootstrap_ci.tex",
        "Bootstrap confidence intervals for key consumer penalties",
        "tab:consumer-bootstrap-ci",
        column_spec="|p{0.10\\linewidth}|p{0.20\\linewidth}|r|r|p{0.14\\linewidth}|r|p{0.14\\linewidth}|",
    )
    write_latex_table(
        compact_effect_table(producer_effects),
        latex_dir / "producer_paired_effects.tex",
        "Matched-pair effect summary for key producer penalties",
        "tab:producer-paired-effects",
        column_spec="|p{0.10\\linewidth}|p{0.22\\linewidth}|r|r|r|r|p{0.10\\linewidth}|",
    )
    write_latex_table(
        compact_effect_table(consumer_effects),
        latex_dir / "consumer_paired_effects.tex",
        "Matched-pair effect summary for key consumer penalties",
        "tab:consumer-paired-effects",
        column_spec="|p{0.10\\linewidth}|p{0.22\\linewidth}|r|r|r|r|p{0.10\\linewidth}|",
    )
    write_latex_table(
        compact_factor_table(factor_top),
        latex_dir / "factor_sensitivity_top.tex",
        "Top factor-sensitivity results for selected producer and consumer penalties",
        "tab:factor-sensitivity-top",
        column_spec="|p{0.10\\linewidth}|p{0.08\\linewidth}|p{0.18\\linewidth}|p{0.15\\linewidth}|p{0.12\\linewidth}|p{0.12\\linewidth}|r|",
    )

    manifest = {
        "pack_dir": str(pack_dir),
        "bootstrap_samples": args.bootstrap_samples,
        "seed": args.seed,
        "outputs": sorted(str(path.relative_to(pack_dir)) for path in csv_dir.glob("*.csv"))
        + sorted(str(path.relative_to(pack_dir)) for path in latex_dir.glob("*.tex")),
    }
    (statistics_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
