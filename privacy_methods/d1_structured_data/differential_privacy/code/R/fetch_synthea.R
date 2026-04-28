# scripts/01_fetch_synthea.R

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(purrr)
  library(stringr)
})

raw_dir <- getOption("dp.raw_dir", file.path("data", "raw"))
processed_dir <- getOption("dp.processed_dir", file.path("data", "processed"))
output_dir <- getOption("dp.output_dir", file.path("data", "output"))

dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

synthea_zip_url <- "https://raw.githubusercontent.com/synthetichealth/synthea-sample-data/main/downloads/latest/synthea_sample_data_csv_latest.zip"
zip_path <- file.path(raw_dir, "synthea_sample_data_csv_latest.zip")
unzip_dir <- file.path(raw_dir, "synthea_csv")

message("Downloading Synthea sample ZIP...")
download.file(synthea_zip_url, destfile = zip_path, mode = "wb")

if (dir.exists(unzip_dir)) {
  unlink(unzip_dir, recursive = TRUE, force = TRUE)
}
dir.create(unzip_dir, recursive = TRUE, showWarnings = FALSE)

message("Unzipping...")
utils::unzip(zip_path, exdir = unzip_dir)

csv_files <- list.files(unzip_dir, pattern = "\\.csv$", full.names = TRUE, recursive = TRUE)
if (length(csv_files) == 0) {
  stop("No CSV files found after unzip. Please check the download URL or ZIP contents.")
}

read_one <- function(path) {
  suppressMessages(readr::read_csv(path, show_col_types = FALSE, progress = FALSE))
}

dfs <- purrr::map(csv_files, read_one)
names(dfs) <- tools::file_path_sans_ext(basename(csv_files))

saveRDS(dfs, file = file.path(processed_dir, "synthea_tables.rds"))

message("Available tables:")
print(sort(names(dfs)))

inventory <- tibble(
  table_name = names(dfs),
  n_rows = purrr::map_int(dfs, nrow),
  n_cols = purrr::map_int(dfs, ncol)
)

write_csv(inventory, file.path(output_dir, "table_inventory.csv"))
message("Step 1 complete.")