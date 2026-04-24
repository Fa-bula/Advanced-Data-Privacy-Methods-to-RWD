"""Benchmark runner scaffold.

This script provides the CLI skeleton for running this benchmark.
It currently writes stub outputs; the assigned group should replace the
body of `main()` with real benchmark logic.

Expected behavior once implemented:
- Accept a dataset name or local path
- Run the baseline and privacy-preserving method(s)
- Write:
    ../results/<dataset>/<run_id>/metrics.json
    ../results/<dataset>/<run_id>/params.json
"""

from __future__ import annotations

from dataclasses import dataclass
import argparse
from pathlib import Path
from datetime import datetime
import logging
import json

from descriptive import do_descriptive
from common import write_benchmark_result

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

METHOD_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = Path(__file__).resolve().parent.parent.parent.parent.parent / 'data'


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    # common args (as a parent for subparsers)
    parent = argparse.ArgumentParser(add_help=False)
    parent.add_argument("--dataset", default="Synthea", help="Dataset name (see datasets/datasets.yaml)")
    parent.add_argument("--data-path", default=DATA_DIR / "synthea", help="Optional path to local data under data/")
    parent.add_argument("--input-table", default="observations.csv", help="Name of input file to run on")
    parent.add_argument("--filter", default="", help="Optional query to filter the input table, e.g. 'VALUE > 0'")
    parent.add_argument("--seed", type=int, default=0)

    subparsers = parser.add_subparsers(dest="cmd", required=True)

    p_descriptive = subparsers.add_parser("descriptive", parents=[parent], help="DP for descriptive statistics")
    p_descriptive.add_argument("--variable", required=True, type=str, help="Variable to compute the descriptive statistic for.")
    p_descriptive.add_argument("--bounds", required=True, nargs=2, type=float, help="Public bounds for the descriptive statistic.")
    p_descriptive.add_argument("--R", default=50, type=int, help="Number of repetitions for each method to estimate utility.")
    p_descriptive.add_argument("--epsilon_list", default=[round(i * 0.1, 1) for i in range(1, 10)], nargs="+", type=float, help="Privacy loss budget(s) for DP methods.")
    p_descriptive.set_defaults(func=do_descriptive)

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    run_id = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    out = METHOD_DIR / "results" / args.dataset / run_id
    out.mkdir(parents=True, exist_ok=True)

    params = {k: v for k, v in args._get_kwargs() if k not in ["func", "data_path"]}
    # metrics = {"status": "stub", "note": "Replace with real benchmark logic. See README.md for planned methods and metrics."}
    result = args.func(args)
    write_benchmark_result(result, out)
    (out / "params.json").write_text(json.dumps(params, indent=2))
    # (out / "metrics.json").write_text(json.dumps(metrics, indent=2))
    logging.info(f"Wrote outputs to: {out}")


if __name__ == "__main__":
    main()
