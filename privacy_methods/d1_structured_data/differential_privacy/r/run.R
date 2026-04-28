# Benchmark runner scaffold
#
# This script provides the CLI skeleton for running this benchmark.
# It currently writes stub outputs; the assigned group should replace the
# body with real benchmark logic.
#
# Expected behavior once implemented:
# - Accept a dataset name or local path
# - Run the baseline and privacy-preserving method(s)
# - Write:
#     ../results/<dataset>/<run_id>/metrics.json
#     ../results/<dataset>/<run_id>/params.json

# library(jsonlite)
# 
# method_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile), ".."))
# 
# args <- commandArgs(trailingOnly = TRUE)
# dataset <- ifelse(length(args) >= 1, args[1], "(local)")
# seed <- ifelse(length(args) >= 2, as.integer(args[2]), 0L)
# 
# run_id <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
# out_dir <- file.path(method_dir, "results", dataset, run_id)
# dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
# 
# params <- list(dataset = dataset, seed = seed)
# metrics <- list(status = "stub", note = "Replace with real benchmark logic. See README.md for planned methods and metrics.")
# 
# write_json(params, file.path(out_dir, "params.json"), pretty = TRUE, auto_unbox = TRUE)
# write_json(metrics, file.path(out_dir, "metrics.json"), pretty = TRUE, auto_unbox = TRUE)
# cat("Wrote stub outputs to:", out_dir, "\n")

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(jsonlite)
  library(readr)
  library(dplyr)
})

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)

if (length(file_arg) == 0) {
  stop("Please run this script using Rscript run.R [dataset] [seed]")
}

script_path <- normalizePath(sub("^--file=", "", file_arg[1]))
run_dir <- dirname(script_path)                                # .../differential_privacy/r
method_dir <- normalizePath(file.path(run_dir, ".."))          # .../differential_privacy
code_dir <- normalizePath(file.path(method_dir, "code", "R"))  # .../differential_privacy/code/R

args <- commandArgs(trailingOnly = TRUE)
dataset <- ifelse(length(args) >= 1, args[1], "(local)")
seed <- ifelse(length(args) >= 2, as.integer(args[2]), 0L)

set.seed(seed)

run_id <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
out_dir <- file.path(method_dir, "results", dataset, run_id)

raw_dir <- file.path(out_dir, "raw")
processed_dir <- file.path(out_dir, "processed")
output_dir <- file.path(out_dir, "output")

dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

params <- list(
  dataset = dataset,
  seed = seed,
  run_id = run_id,
  method = "differential_privacy_r",
  epsilon = 1.0,
  delta = 1e-6
)

write_json(params, file.path(out_dir, "params.json"), pretty = TRUE, auto_unbox = TRUE)

options(
  dp.raw_dir = raw_dir,
  dp.processed_dir = processed_dir,
  dp.output_dir = output_dir,
  dp.dataset = dataset,
  dp.seed = seed
)

cat("Running pipeline...\n")
cat("run_dir    :", run_dir, "\n")
cat("method_dir :", method_dir, "\n")
cat("code_dir   :", code_dir, "\n")
cat("out_dir    :", out_dir, "\n")

source(file.path(code_dir, "fetch_synthea.R"))
source(file.path(code_dir, "analyze_synthea.R"))
source(file.path(code_dir, "prepare_dp_queries.R"))
source(file.path(code_dir, "apply_dp.R"))
source(file.path(code_dir, "evaluate_dp_privacy_utility.R"))
source(file.path(code_dir, "run_dp_analyses.R"))

safe_read <- function(path) {
  if (file.exists(path)) read_csv(path, show_col_types = FALSE) else NULL
}

mart <- safe_read(file.path(processed_dir, "analytic_mart.csv"))
eval_uni <- safe_read(file.path(output_dir, "eval_univariate_counts.csv"))
eval_cross <- safe_read(file.path(output_dir, "eval_crosstabs.csv"))
eval_hist <- safe_read(file.path(output_dir, "eval_histograms.csv"))
eval_means <- safe_read(file.path(output_dir, "eval_bounded_means.csv"))
auc_tbl <- safe_read(file.path(output_dir, "original_logistic_auc.csv"))
lin_summary <- safe_read(file.path(output_dir, "original_linear_summary.csv"))

metrics <- list(
  status = "success",
  n_patients = if (!is.null(mart)) nrow(mart) else NA,
  mean_abs_error_univariate = if (!is.null(eval_uni)) mean(eval_uni$mean_abs_error, na.rm = TRUE) else NA,
  mean_abs_error_crosstabs = if (!is.null(eval_cross)) mean(eval_cross$mean_abs_error, na.rm = TRUE) else NA,
  mean_abs_error_histograms = if (!is.null(eval_hist)) mean(eval_hist$mean_abs_error, na.rm = TRUE) else NA,
  mean_abs_error_bounded_means = if (!is.null(eval_means)) mean(eval_means$abs_error, na.rm = TRUE) else NA,
  logistic_auc = if (!is.null(auc_tbl) && "value" %in% names(auc_tbl)) auc_tbl$value[1] else NA,
  linear_r_squared = if (!is.null(lin_summary) && "r.squared" %in% names(lin_summary)) lin_summary[["r.squared"]][1] else NA
)

write_json(metrics, file.path(out_dir, "metrics.json"), pretty = TRUE, auto_unbox = TRUE)

cat("Done.\n")
cat("Outputs written to:", out_dir, "\n")