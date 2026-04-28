install.packages(c(
  "tidyverse", "jsonlite", "readr", "stringr", "lubridate",
  "survival", "pROC", "broom", "styler"
))

source("scripts/01_fetch_synthea.R")
source("scripts/02_analyze_synthea.R")
source("scripts/03_prepare_dp_queries.R")
source("scripts/04_apply_dp.R")
source("scripts/05_evaluate_dp_privacy_utility.R")
source("scripts/06_run_dp_analyses.R")