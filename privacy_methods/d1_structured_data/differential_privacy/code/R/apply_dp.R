# scripts/04_apply_dp.R

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(jsonlite)
  library(tidyr)
})

raw_dir <- getOption("dp.raw_dir", file.path("data", "raw"))
processed_dir <- getOption("dp.processed_dir", file.path("data", "processed"))
output_dir <- getOption("dp.output_dir", file.path("data", "output"))

mart <- read_csv(file.path(processed_dir, "analytic_mart.csv"), show_col_types = FALSE)
dp_config <- read_json(file.path(output_dir, "dp_config.json"), simplifyVector = TRUE)
release_plan <- read_json(file.path(output_dir, "release_plan.json"), simplifyVector = TRUE)
# ----------------------------
# DP helper functions
# ----------------------------

rlaplace <- function(n, mu = 0, b = 1) {
  u <- stats::runif(n, min = -0.5, max = 0.5)
  mu - b * sign(u) * log(1 - 2 * abs(u))
}

dp_count_by <- function(data, var, epsilon) {
  sens <- 1
  scale <- sens / epsilon

  out <- data %>%
    count(.data[[var]], name = "true_count") %>%
    rename(level = 1) %>%
    mutate(
      level = as.character(level),
      dp_count_raw = true_count + rlaplace(n(), 0, scale),
      dp_count = pmax(round(dp_count_raw), 0)
    ) %>%
    mutate(variable = var) %>%
    select(variable, level, true_count, dp_count)

  out
}

dp_count_by2 <- function(data, var1, var2, epsilon) {
  sens <- 1
  scale <- sens / epsilon

  out <- data %>%
    count(.data[[var1]], .data[[var2]], name = "true_count") %>%
    rename(level1 = 1, level2 = 2) %>%
    mutate(
      level1 = as.character(level1),
      level2 = as.character(level2),
      dp_count_raw = true_count + rlaplace(n(), 0, scale),
      dp_count = pmax(round(dp_count_raw), 0)
    ) %>%
    mutate(var1 = var1, var2 = var2) %>%
    select(var1, var2, level1, level2, true_count, dp_count)

  out
}
dp_histogram <- function(data, var, breaks, epsilon) {
  x <- data[[var]]
  bins <- cut(x, breaks = breaks, include.lowest = TRUE, right = FALSE)
  sens <- 1
  scale <- sens / epsilon

  out <- tibble(bin = bins) %>%
    count(bin, name = "true_count") %>%
    mutate(
      dp_count_raw = true_count + rlaplace(n(), 0, scale),
      dp_count = pmax(round(dp_count_raw), 0),
      variable = var
    ) %>%
    select(variable, bin, true_count, dp_count)

  out
}

dp_bounded_mean <- function(data, var, lower, upper, epsilon) {
  x <- data[[var]]
  x <- pmin(pmax(x, lower), upper)
  n <- length(x)
  true_mean <- mean(x, na.rm = TRUE)

  # Sensitivity of bounded mean with one protected row
  sens <- (upper - lower) / n
  scale <- sens / epsilon

  dp_mean <- true_mean + rlaplace(1, 0, scale)

  tibble(
    variable = var,
    lower = lower,
    upper = upper,
    n = n,
    true_mean = true_mean,
    dp_mean = dp_mean
  )
}

# ----------------------------
# Allocate budgets
# ----------------------------

eps_total <- dp_config$epsilon_total
split <- dp_config$budget_split

eps_uni <- eps_total * split$univariate_counts
eps_cross <- eps_total * split$crosstabs
eps_hist <- eps_total * split$histograms
eps_mean <- eps_total * split$bounded_means
eps_model <- eps_total * split$modeling

uni_plan <- release_plan$univariate_counts
cross_plan <- release_plan$crosstabs
hist_plan <- release_plan$histograms
mean_plan <- release_plan$bounded_means

eps_uni_each <- eps_uni / length(uni_plan)
eps_cross_each <- eps_cross / length(cross_plan)
eps_hist_each <- eps_hist / length(hist_plan)
eps_mean_each <- eps_mean / length(mean_plan)

# ----------------------------
# Run DP releases
# ----------------------------

dp_uni <- bind_rows(lapply(seq_len(nrow(uni_plan)), function(i) {
  dp_count_by(mart, uni_plan$var[i], eps_uni_each)
}))

dp_cross <- bind_rows(lapply(seq_len(nrow(cross_plan)), function(i) {
  dp_count_by2(mart, cross_plan$var1[i], cross_plan$var2[i], eps_cross_each)
}))

dp_hist <- bind_rows(lapply(seq_len(nrow(hist_plan)), function(i) {
  dp_histogram(mart, hist_plan$var[i], hist_plan$breaks[[i]], eps_hist_each)
}))

dp_means <- bind_rows(lapply(seq_len(nrow(mean_plan)), function(i) {
  dp_bounded_mean(
    mart,
    mean_plan$var[i],
    mean_plan$lower[i],
    mean_plan$upper[i],
    eps_mean_each
  )
}))

write_csv(dp_uni,   file.path(output_dir, "dp_univariate_counts.csv"))
write_csv(dp_cross, file.path(output_dir, "dp_crosstabs.csv"))
write_csv(dp_hist,  file.path(output_dir, "dp_histograms.csv"))
write_csv(dp_means, file.path(output_dir, "dp_bounded_means.csv"))

budget_audit <- tibble::tribble(
  ~component,            ~epsilon_allocated,
  "univariate_counts",   eps_uni,
  "crosstabs",           eps_cross,
  "histograms",          eps_hist,
  "bounded_means",       eps_mean,
  "modeling_reserved",   eps_model,
  "total",               eps_uni + eps_cross + eps_hist + eps_mean + eps_model
)

write_csv(budget_audit, file.path(output_dir, "dp_budget_audit.csv"))
message("Step 4 complete.")
