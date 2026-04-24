from io import BytesIO
import pandas as pd
import argparse
import opendp.prelude as dp
import logging
import math
import statistics as stats
import matplotlib.pyplot as plt

from common import BenchmarkResult

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

def do_mean(args: argparse.Namespace) -> None:
    dp.enable_features("contrib")

    # Read and clean the numeric column you want to average
    df = pd.read_csv(args.data_path / args.input_table)
    df = df.query(args.filter) if args.filter else df
    logging.info(f"Read {len(df)} rows after filtering with query: {args.filter}")
    values = (
        pd.to_numeric(df[args.variable], errors="coerce")
        .dropna()
        .astype(float)
        .tolist()
    )
    actual_mean = sum(values) / len(values)

    bounds = tuple(args.bounds)
    imputed_value = (bounds[0] + bounds[1]) / 2
    logging.info(f"Bounds for variable '{args.variable}': {args.bounds}, imputed value: {imputed_value}")
    results = []

    for epsilon in args.epsilon_list:
        dp_means = []
        dp_counts = []

        for _ in range(args.R):
            context = dp.Context.compositor(
                data=values,
                privacy_unit=dp.unit_of(contributions=1),
                privacy_loss=dp.loss_of(epsilon=epsilon),
                split_evenly_over=2,
            )

            count_query = context.query().count().laplace()
            dp_count = count_query.release()

            mean_query = (
                context.query()
                .impute_constant(imputed_value)
                .clamp(bounds)
                .resize(size=dp_count, constant=imputed_value)
                .mean()
                .laplace()
            )
            dp_mean = mean_query.release()

            dp_counts.append(dp_count)
            dp_means.append(dp_mean)

        # Utility metrics for this epsilon
        abs_errors = [abs(x - actual_mean) for x in dp_means]
        sq_errors = [(x - actual_mean) ** 2 for x in dp_means]
        rel_errors = [
            abs(x - actual_mean) / abs(actual_mean) if actual_mean != 0 else float("nan")
            for x in dp_means
        ]

        row = {
            "epsilon": epsilon,
            "R": args.R,
            "actual_mean": actual_mean, 
            "dp_mean_avg": stats.mean(dp_means),
            "dp_mean_std": stats.pstdev(dp_means) if len(dp_means) > 1 else 0.0,
            "mae": stats.mean(abs_errors),
            "rmse": math.sqrt(stats.mean(sq_errors)),
            "mape": stats.mean(rel_errors),
            "dp_count_avg": stats.mean(dp_counts),
            "dp_count_std": stats.pstdev(dp_counts) if len(dp_counts) > 1 else 0.0,
        }
        results.append(row)

    summary_df = pd.DataFrame(results)
    summary_df = summary_df.sort_values("epsilon")

    def make_plot(summary_df):
        summary_df = summary_df.sort_values("epsilon")

        fig, ax = plt.subplots()
        ax.plot(summary_df["epsilon"], summary_df["rmse"], marker="o")
        ax.set_xscale("linear")
        ax.set_xlabel("Epsilon")
        ax.set_ylabel("RMSE")
        ax.set_xticks(summary_df["epsilon"])
        ax.set_title("Epsilon vs RMSE")
        ax.grid(True, which="both", alpha=0.3)

        buf = BytesIO()
        fig.tight_layout()
        fig.savefig(buf, format="png", dpi=300, bbox_inches="tight")
        plt.close(fig)

        buf.seek(0)
        return buf.getvalue()
    return BenchmarkResult(summary=summary_df, plots={"epsilon_vs_rmse.png": make_plot(summary_df)})
