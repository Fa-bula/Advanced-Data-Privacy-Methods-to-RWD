# scripts/06_run_dp_analyses.R

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(survival)
  library(broom)
  library(pROC)
})

raw_dir <- getOption("dp.raw_dir", file.path("data", "raw"))
processed_dir <- getOption("dp.processed_dir", file.path("data", "processed"))
output_dir <- getOption("dp.output_dir", file.path("data", "output"))
mart <- read_csv(file.path(processed_dir, "analytic_mart.csv"), show_col_types = FALSE)
dp_means <- read_csv(file.path(output_dir, "dp_bounded_means.csv"), show_col_types = FALSE)
dp_uni <- read_csv(file.path(output_dir, "dp_univariate_counts.csv"), show_col_types = FALSE)

# ----------------------------
# Original utility analyses
# ----------------------------

# Logistic classification: death event
mart2 <- mart %>%
  mutate(
    gender = as.factor(gender),
    chronic_flag = as.factor(chronic_flag)
  ) %>%
  filter(
    complete.cases(event, age, gender, chronic_flag, encounter_count)
  )

# Remove unused factor levels
mart2 <- mart2 %>%
  mutate(
    gender = droplevels(gender),
    chronic_flag = droplevels(chronic_flag)
  )

# Start with candidate predictors
predictors <- c("age", "encounter_count")

if (nlevels(mart2$gender) >= 2) {
  predictors <- c(predictors, "gender")
} else {
  message("Dropping gender: only one level present.")
}

if (nlevels(mart2$chronic_flag) >= 2) {
  predictors <- c(predictors, "chronic_flag")
} else {
  message("Dropping chronic_flag: only one level present.")
}

# Also ensure outcome has 2 classes
if (length(unique(mart2$event)) < 2) {
  stop("event has fewer than 2 classes. Logistic model cannot be fit.")
}

logit_formula <- as.formula(
  paste("event ~", paste(predictors, collapse = " + "))
)

logit_fit <- glm(logit_formula, data = mart2, family = binomial())

logit_pred <- predict(logit_fit, type = "response")
auc_val <- as.numeric(pROC::auc(mart2$event, logit_pred))

logit_coef <- broom::tidy(logit_fit)
write_csv(logit_coef, file.path(output_dir, "original_logistic_coefficients.csv"))
write_csv(tibble(metric = "AUC", value = auc_val), file.path(output_dir, "original_logistic_auc.csv"))

# Linear regression: survival days
lin_data <- mart %>%
  mutate(
    chronic_flag = as.factor(chronic_flag)
  ) %>%
  filter(
    complete.cases(survival_days, age, chronic_flag, encounter_count, condition_count)
  ) %>%
  mutate(
    chronic_flag = droplevels(chronic_flag)
  )

lin_predictors <- c("age", "encounter_count", "condition_count")

if (nlevels(lin_data$chronic_flag) >= 2) {
  lin_predictors <- c(lin_predictors, "chronic_flag")
} else {
  message("Dropping chronic_flag: only one level present in linear model.")
}

lin_formula <- as.formula(
  paste("survival_days ~", paste(lin_predictors, collapse = " + "))
)

lin_fit <- lm(lin_formula, data = lin_data)

lin_summary <- broom::glance(lin_fit)
lin_coef <- broom::tidy(lin_fit)

write_csv(lin_coef, file.path(output_dir, "original_linear_coefficients.csv"))
write_csv(lin_summary, file.path(output_dir, "original_linear_summary.csv"))

# Kaplan-Meier summary
km_fit <- survival::survfit(Surv(survival_days, event) ~ chronic_flag, data = mart2)

km_tbl <- tibble(
  strata = names(km_fit$strata),
  n = as.integer(km_fit$strata)
)

write_csv(km_tbl, file.path(output_dir, "original_km_summary.csv"))
# ----------------------------
# DP descriptive comparisons
# ----------------------------

dp_age_mean <- dp_means %>% filter(variable == "age")
dp_enc_mean <- dp_means %>% filter(variable == "encounter_count")
dp_surv_mean <- dp_means %>% filter(variable == "survival_days")

dp_gender_counts <- dp_uni %>% filter(variable == "gender")
dp_event_counts <- dp_uni %>% filter(variable == "event")

dp_analysis_summary <- bind_rows(
  tibble(
    analysis = "mean_age",
    original = dp_age_mean$true_mean,
    dp_value = dp_age_mean$dp_mean
  ),
  tibble(
    analysis = "mean_encounter_count",
    original = dp_enc_mean$true_mean,
    dp_value = dp_enc_mean$dp_mean
  ),
  tibble(
    analysis = "mean_survival_days",
    original = dp_surv_mean$true_mean,
    dp_value = dp_surv_mean$dp_mean
  )
) %>%
  mutate(abs_error = abs(dp_value - original))

write_csv(dp_analysis_summary, file.path(output_dir, "dp_analysis_summary.csv"))
message("Step 6 complete.")
