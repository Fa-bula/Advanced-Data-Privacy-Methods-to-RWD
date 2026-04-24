from dataclasses import dataclass
import pandas as pd
from pathlib import Path


@dataclass
class BenchmarkResult:
    summary: pd.DataFrame
    plots: dict[str, bytes]  # e.g. {"dp_mean_vs_epsilon.png": bytes, ...}


def write_benchmark_result(result: BenchmarkResult, out_dir: str):
    out_path = Path(out_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    # 1) save summary table
    result.summary.to_csv(out_path / "summary.csv", index=False)

    # optional: also save as parquet
    # result.summary.to_parquet(out_path / "summary.parquet", index=False)

    # 2) save plots
    for filename, buf in result.plots.items():
        file_path = out_path / filename

        with open(file_path, "wb") as f:
            f.write(buf)