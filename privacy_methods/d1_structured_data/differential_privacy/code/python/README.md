# Data Type 1 — Structured Data: Differential Privacy

## Purpose (plain language)
Differential Privacy (DP) applied to structured tabular clinical data. This covers both:
- **DP analytics** — privacy-preserving counts, means, and distributions (OpenDP / SmartNoise)
- **DP models** — DP logistic regression (with optional elastic-net regularization) and DP-SGD neural nets for ICU prediction tasks (Opacus)

## What this privacy method will produce
- DP vs non-DP summary tables (counts, means, histograms)
- Utility-vs-epsilon curves (privacy–utility trade-off)
- Predictive performance metrics at varying privacy budgets
- All outputs saved locally under `results/`

## Datasets (recommended starting points)
See `datasets/datasets.yaml` and dataset cards in `datasets/`.

## Methods in scope (initial)
- DP analytics: OpenDP / SmartNoise (counts, means, histograms)
- DP-SGD tabular models: Opacus (logistic regression, neural nets)
- DP logistic regression (with optional elastic-net regularization)

## Benchmark tasks
- Demographic distribution tables and risk factor summaries (DP analytics)
- ICU mortality / readmission prediction (DP models)

## Metrics (v0)
- Utility metrics (e.g., AUROC, F1, calibration)
- Privacy metrics (epsilon, delta, utility-vs-epsilon curves)
- Privacy/attack metrics: membership inference AUROC, attribute inference accuracy
- Basic fairness checks: performance disparities across demographic subgroups (optional)

## How to run
- Crete virtual environment, if not yet created:
 `python3 -m venv .venv`
- `source .venv/bin/activate`
- `cd privacy_methods/d1_structured_data/differential_privacy/python`
- `pip install -r requirements.txt`
- `python run.py --help`
