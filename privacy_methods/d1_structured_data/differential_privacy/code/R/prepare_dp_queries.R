# scripts/03_prepare_dp_queries.R

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
  library(readr)
})
raw_dir <- getOption("dp.raw_dir", file.path("data", "raw"))
processed_dir <- getOption("dp.processed_dir", file.path("data", "processed"))
output_dir <- getOption("dp.output_dir", file.path("data", "output"))
mart <- read_csv(file.path(processed_dir, "analytic_mart.csv"), show_col_types = FALSE)

# Privacy budget setup
dp_config <- list(
  epsilon_total = 1.0,
  delta = 1e-6,
  protected_unit = "patient",
  mechanisms = list(
    counts = "laplace",
    means = "laplace",
    histograms = "laplace"
  ),
  budget_split = list(
    univariate_counts = 0.25,
    crosstabs = 0.20,
    histograms = 0.20,
    bounded_means = 0.20,
    modeling = 0.15
  )
)

# Release definitions
release_plan <- list(
  univariate_counts = list(
    list(type = "count_by", var = "gender"),
    list(type = "count_by", var = "race"),
    list(type = "count_by", var = "ethnicity"),
    list(type = "count_by", var = "age_group"),
    list(type = "count_by", var = "event"),
    list(type = "count_by", var = "chronic_flag")
  ),
  crosstabs = list(
    list(type = "count_by2", var1 = "gender", var2 = "event"),
    list(type = "count_by2", var1 = "race", var2 = "chronic_flag"),
    list(type = "count_by2", var1 = "age_group", var2 = "util_high")
  ),
  histograms = list(
    list(type = "histogram", var = "age", breaks = c(0, 18, 35, 50, 65, 101)),
    list(type = "histogram", var = "encounter_count", breaks = c(0, 1, 3, 5, 10, 20, 51)),
    list(type = "histogram", var = "condition_count", breaks = c(0, 1, 2, 5, 10, 21))
  ),
  bounded_means = list(
    list(type = "bounded_mean", var = "age", lower = 0, upper = 100),
    list(type = "bounded_mean", var = "encounter_count", lower = 0, upper = 50),
    list(type = "bounded_mean", var = "condition_count", lower = 0, upper = 20),
    list(type = "bounded_mean", var = "survival_days", lower = 0, upper = 3650)
  ),
  modeling = list(
    list(
      type = "logistic_inputs", outcome = "event",
      predictors = c("age", "gender", "chronic_flag", "encounter_count")
    ),
    list(
      type = "linear_inputs", outcome = "survival_days",
      predictors = c("age", "chronic_flag", "encounter_count", "condition_count")
    )
  )
)

write_json(dp_config, file.path(output_dir, "dp_config.json"), pretty = TRUE, auto_unbox = TRUE)
write_json(release_plan, file.path(output_dir, "release_plan.json"), pretty = TRUE, auto_unbox = TRUE)

message("Step 3 complete.")
