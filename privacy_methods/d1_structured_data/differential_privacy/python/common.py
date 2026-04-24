from dataclasses import dataclass
import pandas as pd
from pathlib import Path
import opendp.prelude as dp
import logging
from typing import Optional
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

def get_values(csv_path: Path, filter: Optional[str], variable: str):
    dp.enable_features("contrib")

    # Read and clean the numeric column you want to average
    df = pd.read_csv(csv_path)
    df = df.query(filter) if filter else df
    logging.info(f"Read {len(df)} rows after filtering with query: {filter}")
    values = (
        pd.to_numeric(df[variable], errors="coerce")
        .dropna()
        .astype(float)
        .tolist()
    )
    return values

def check_bounds(values: list, bounds: tuple):
    if min(values) < bounds[0]:
        raise ValueError(f"Some actual values below lower bound {bounds[0]}")
    if max(values) > bounds[1]:
        raise ValueError(f"Some actual values above upper bound {bounds[1]}")