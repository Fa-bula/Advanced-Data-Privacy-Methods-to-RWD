# scripts/05_evaluate_dp_privacy_utility.R

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(jsonlite)
})
dp_config <- read_json(file.path(output_dir, "dp_config.json"), simplifyVector = TRUE)
budget_audit <- read_csv(file.path(output_dir,"dp_budget_audit.csv"), show_col_types = FALSE)

dp_uni <- read_csv(file.path(output_dir, "dp_univariate_counts.csv"), show_col_types = FALSE)
dp_cross <- read_csv(file.path(output_dir, "dp_crosstabs.csv"), show_col_types = FALSE)
dp_hist  <- read_csv(file.path(output_dir, "dp_histograms.csv"), show_col_types = FALSE)
dp_means <- read_csv(file.path(output_dir, "dp_bounded_means.csv"), show_col_types = FALSE)

# Utility summaries
uni_eval <- dp_uni %>%
  mutate(
    abs_error = abs(dp_count - true_count),
    rel_error = if_else(true_count > 0, abs_error / true_count, NA_real_)
  ) %>%
  group_by(variable) %>%
  summarise(
    mean_abs_error = mean(abs_error, na.rm = TRUE),
    median_abs_error = median(abs_error, na.rm = TRUE),
    mean_rel_error = mean(rel_error, na.rm = TRUE),
    .groups = "drop"
  )

cross_eval <- dp_cross %>%
  mutate(
    abs_error = abs(dp_count - true_count),
    rel_error = if_else(true_count > 0, abs_error / true_count, NA_real_)
  ) %>%
  group_by(var1, var2) %>%
  summarise(
    mean_abs_error = mean(abs_error, na.rm = TRUE),
    median_abs_error = median(abs_error, na.rm = TRUE),
    mean_rel_error = mean(rel_error, na.rm = TRUE),
    .groups = "drop"
  )

hist_eval <- dp_hist %>%
  mutate(
    abs_error = abs(dp_count - true_count),
    rel_error = if_else(true_count > 0, abs_error / true_count, NA_real_)
  ) %>%
  group_by(variable) %>%
  summarise(
    mean_abs_error = mean(abs_error, na.rm = TRUE),
    median_abs_error = median(abs_error, na.rm = TRUE),
    mean_rel_error = mean(rel_error, na.rm = TRUE),
    .groups = "drop"
  )

means_eval <- dp_means %>%
  mutate(
    abs_error = abs(dp_mean - true_mean),
    rel_error = if_else(abs(true_mean) > 1e-10, abs_error / abs(true_mean), NA_real_)
  ) %>%
  select(variable, true_mean, dp_mean, abs_error, rel_error)

write_csv(uni_eval, file.path(output_dir, "eval_univariate_counts.csv"))
write_csv(cross_eval, file.path(output_dir, "eval_crosstabs.csv"))
write_csv(hist_eval, file.path(output_dir, "eval_histograms.csv"))
write_csv(means_eval, file.path(output_dir,"eval_bounded_means.csv"))

privacy_summary <- tibble::tribble(
  ~item, ~value,
  "protected_unit", dp_config$protected_unit,
  "epsilon_total", as.character(dp_config$epsilon_total),
  "delta", as.character(dp_config$delta),
  "counts_mechanism", dp_config$mechanisms$counts,
  "means_mechanism", dp_config$mechanisms$means,
  "histograms_mechanism", dp_config$mechanisms$histograms
)


write_csv(privacy_summary, file.path(output_dir, "privacy_summary.csv"))
message("Budget audit:")
print(budget_audit)

message("Privacy summary:")
print(privacy_summary)

message("Step 5 complete.")