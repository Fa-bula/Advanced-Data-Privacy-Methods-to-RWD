from io import BytesIO
import argparse
import logging
import math
import statistics as stats

import matplotlib.pyplot as plt
import pandas as pd
import opendp.prelude as dp

from common import BenchmarkResult, get_values, check_bounds

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

def build_context(values, epsilon: float, num_queries: int):
    return dp.Context.compositor(
        data=values,
        privacy_unit=dp.unit_of(contributions=1),
        privacy_loss=dp.loss_of(epsilon=epsilon),
        split_evenly_over=num_queries,
    )

def run_dp_count(values, epsilon: float) -> int:
    context = build_context(values, epsilon, 1)
    return context.query().count().laplace().release()

def run_dp_mean(values, bounds, epsilon: float, dp_count: int, imputed_value: float) -> float:
    context = build_context(values, epsilon, 2)
    return (
        context.query()
        .impute_constant(imputed_value)
        .clamp(bounds)
        .resize(size=dp_count, constant=imputed_value)
        .mean()
        .laplace()
        .release()
    )

def summarize_trials(actual_value, samples):
    abs_errors = [abs(x - actual_value) for x in samples]
    sq_errors = [(x - actual_value) ** 2 for x in samples]
    rel_errors = [
        abs(x - actual_value) / abs(actual_value) if actual_value != 0 else float("nan")
        for x in samples
    ]
    return {
        "dp_average": stats.mean(samples),
        "dp_std": stats.pstdev(samples) if len(samples) > 1 else 0.0,
        "mae": stats.mean(abs_errors),
        "rmse": math.sqrt(stats.mean(sq_errors)),
        "mape": stats.mean(rel_errors),
    }

def make_plot(summary_df):
    summary_df = summary_df.sort_values("epsilon")

    fig, ax = plt.subplots()
    ax.plot(summary_df["epsilon"], summary_df["rmse"], marker="o")
    ax.set_xlabel("Epsilon")
    ax.set_ylabel("RMSE")
    ax.set_title("Epsilon vs RMSE")
    ax.grid(True, alpha=0.3)

    buf = BytesIO()
    fig.tight_layout()
    fig.savefig(buf, format="png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    buf.seek(0)
    return buf.getvalue()

def do_mean(args: argparse.Namespace) -> BenchmarkResult:
    values = get_values(args.data_path / args.input_table, args.filter, args.variable)
    bounds = tuple(args.bounds)
    check_bounds(values, bounds)

    actual_values = sum(values) / len(values)
    imputed_value = (bounds[0] + bounds[1]) / 2
    logging.info(
        f"Bounds for variable '{args.variable}': {bounds}, imputed value: {imputed_value}"
    )

    results = []

    for epsilon in args.epsilon_list:
        dp_means = []
        dp_counts = []

        for _ in range(args.R):
            dp_count = run_dp_count(values, epsilon)
            dp_mean = run_dp_mean(values, bounds, epsilon, dp_count, imputed_value)

            dp_counts.append(dp_count)
            dp_means.append(dp_mean)

        summary = summarize_trials(actual_values, dp_means)

        results.append({
            "epsilon": epsilon,
            "R": args.R,
            "statistics": "mean",
            **summary
        })

    summary_df = pd.DataFrame(results).sort_values("epsilon")
    return BenchmarkResult(
        summary=summary_df,
        plots={"epsilon_vs_rmse.png": make_plot(summary_df)},
    )


def do_count(args: argparse.Namespace) -> BenchmarkResult:
    values = get_values(args.data_path / args.input_table, args.filter, args.variable)
    actual_value = len(values)
    results = []
    for epsilon in args.epsilon_list:
        dp_counts = [run_dp_count(values, epsilon) for _ in range(args.R)]
        summary = summarize_trials(actual_value, dp_counts)

        results.append({
            "epsilon": epsilon,
            "R": args.R,
            "statistics": "count",
            **summary
        })

    summary_df = pd.DataFrame(results).sort_values("epsilon")
    return BenchmarkResult(
        summary=summary_df,
        plots={"epsilon_vs_rmse.png": make_plot(summary_df)},
    )