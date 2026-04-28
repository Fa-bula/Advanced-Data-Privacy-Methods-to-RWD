# scripts/02_analyze_synthea.R

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(lubridate)
  library(tidyr)
  library(purrr)
})

raw_dir <- getOption("dp.raw_dir", file.path("data", "raw"))
processed_dir <- getOption("dp.processed_dir", file.path("data", "processed"))
output_dir <- getOption("dp.output_dir", file.path("data", "output"))

dfs <- readRDS(file.path(processed_dir, "synthea_tables.rds"))

required_tables <- c("patients", "encounters", "conditions", "medications", "procedures", "observations")
missing_tbls <- setdiff(required_tables, names(dfs))
if (length(missing_tbls) > 0) {
  stop("Missing required tables: ", paste(missing_tbls, collapse = ", "))
}

patients     <- dfs$patients
encounters   <- dfs$encounters
conditions   <- dfs$conditions
medications  <- dfs$medications
procedures   <- dfs$procedures
observations <- dfs$observations

# Standardize names
names(patients)     <- toupper(names(patients))
names(encounters)   <- toupper(names(encounters))
names(conditions)   <- toupper(names(conditions))
names(medications)  <- toupper(names(medications))
names(procedures)   <- toupper(names(procedures))
names(observations) <- toupper(names(observations))

# Helper
safe_date <- function(x) suppressWarnings(as.Date(x))

# Build patient base
pt <- patients %>%
  mutate(
    BIRTHDATE = safe_date(BIRTHDATE),
    DEATHDATE = safe_date(DEATHDATE),
    is_dead   = if_else(!is.na(DEATHDATE), 1L, 0L),
    age       = floor(as.numeric(difftime(Sys.Date(), BIRTHDATE, units = "days")) / 365.25),
    age       = pmin(pmax(age, 0), 100),
    age_group = cut(
      age,
      breaks = c(-Inf, 17, 34, 49, 64, Inf),
      labels = c("0-17", "18-34", "35-49", "50-64", "65+"),
      right = TRUE
    )
  ) %>%
  transmute(
    patient_id = ID,
    birthdate  = BIRTHDATE,
    deathdate  = DEATHDATE,
    is_dead,
    age,
    age_group,
    gender     = GENDER,
    race       = RACE,
    ethnicity  = ETHNICITY,
    state      = STATE
  )

if (!"patient_id" %in% names(pt)) {
  stop("Could not identify patient ID column in patients table.")
}

# Encounters summary
enc_sum <- encounters %>%
  mutate(
    patient_id = PATIENT,
    enc_start = safe_date(START)
  ) %>%
  group_by(patient_id) %>%
  summarise(
    encounter_count = n(),
    first_encounter = suppressWarnings(min(enc_start, na.rm = TRUE)),
    last_encounter  = suppressWarnings(max(enc_start, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  mutate(
    encounter_count = pmin(encounter_count, 50L)
  )

# Conditions summary
cond_sum <- conditions %>%
  mutate(patient_id = PATIENT) %>%
  group_by(patient_id) %>%
  summarise(
    condition_count = n(),
    .groups = "drop"
  ) %>%
  mutate(
    condition_count = pmin(condition_count, 20L),
    chronic_flag = if_else(condition_count > 0, 1L, 0L)
  )

# Medications summary
med_sum <- medications %>%
  mutate(patient_id = PATIENT) %>%
  group_by(patient_id) %>%
  summarise(
    medication_count = n(),
    .groups = "drop"
  ) %>%
  mutate(medication_count = pmin(medication_count, 30L))

# Procedures summary
proc_sum <- procedures %>%
  mutate(patient_id = PATIENT) %>%
  group_by(patient_id) %>%
  summarise(
    procedure_count = n(),
    .groups = "drop"
  ) %>%
  mutate(procedure_count = pmin(procedure_count, 30L))

# Observations summary
obs_sum <- observations %>%
  mutate(patient_id = PATIENT) %>%
  group_by(patient_id) %>%
  summarise(
    observation_count = n(),
    .groups = "drop"
  ) %>%
  mutate(observation_count = pmin(observation_count, 100L))

# Survival-type endpoints
mart <- pt %>%
  left_join(enc_sum, by = "patient_id") %>%
  left_join(cond_sum, by = "patient_id") %>%
  left_join(med_sum, by = "patient_id") %>%
  left_join(proc_sum, by = "patient_id") %>%
  left_join(obs_sum, by = "patient_id") %>%
  mutate(
    across(c(encounter_count, condition_count, medication_count, procedure_count, observation_count),
           ~replace_na(., 0L)),
    chronic_flag = replace_na(chronic_flag, 0L),
    index_date   = if_else(!is.na(first_encounter), first_encounter, birthdate),
    end_date     = if_else(!is.na(deathdate), deathdate, Sys.Date()),
    survival_days = pmax(as.numeric(end_date - index_date), 0),
    survival_days = pmin(survival_days, 3650),  # bound at 10 years
    event = is_dead,
    util_high = if_else(encounter_count >= 10, 1L, 0L)
  )

# Basic profiling
profile_tbl <- tibble(
  variable = names(mart),
  class = purrr::map_chr(mart, ~ paste(class(.x), collapse = ",")),
  n_missing = purrr::map_int(mart, ~ sum(is.na(.x))),
  n_unique = purrr::map_int(mart, ~ dplyr::n_distinct(.x, na.rm = TRUE))
)

write_csv(profile_tbl, file.path(output_dir, "analytic_mart_profile.csv"))
write_csv(mart, file.path(processed_dir, "analytic_mart.csv"))

# Metadata for DP
dp_metadata <- tibble::tribble(
  ~variable,           ~type,        ~lower, ~upper, ~notes,
  "age",               "numeric",      0,     100,   "Bounded age",
  "encounter_count",   "numeric",      0,      50,   "Clipped encounter count",
  "condition_count",   "numeric",      0,      20,   "Clipped condition count",
  "medication_count",  "numeric",      0,      30,   "Clipped medication count",
  "procedure_count",   "numeric",      0,      30,   "Clipped procedure count",
  "observation_count", "numeric",      0,     100,   "Clipped observation count",
  "survival_days",     "numeric",      0,    3650,   "Bounded survival follow-up",
  "gender",            "categorical", NA,      NA,   "Category release",
  "race",              "categorical", NA,      NA,   "Category release",
  "ethnicity",         "categorical", NA,      NA,   "Category release",
  "state",             "categorical", NA,      NA,   "Category release",
  "age_group",         "categorical", NA,      NA,   "Binned age category",
  "event",             "binary",       0,       1,   "Death indicator",
  "chronic_flag",      "binary",       0,       1,   "Any condition indicator",
  "util_high",         "binary",       0,       1,   "High utilization indicator"
)

write_csv(dp_metadata, file.path(output_dir, "dp_metadata.csv"))
message("Step 2 complete.")
