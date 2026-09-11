# ==============================================================================
# Clean and Combine CFOI Fatality Rate Data (2006-2024)
#
# Purpose: Reads BLS Census of Fatal Occupational Injuries (CFOI) Excel files
# (one per year), extracts fatal injury rates for a subset of industries/
# occupations relevant to this study, combines them across years, and builds
# a wide-format summary table (with an all-years average row).
#
# Data source: U.S. Bureau of Labor Statistics, Census of Fatal Occupational
# Injuries (CFOI) - https://www.bls.gov/iif/fatal-injuries-tables.htm
#
# Inputs:
#   - One .xlsx file per year in data/cfoi_rate, as downloaded from BLS
#
# Outputs:
#   - bls_fatal_injury_rate_all_years.csv
#       Long-format data: one row per Industry x Year, for all matched
#       industries/occupations in `wanted_rows`.
#   - fatal_injury_rate_table.csv
#       Wide-format summary table: one row per year (plus an "Average" row),
#       one column per industry, for the subset of industries in `wanted`
#       used in the manuscript's final tables/figures.
# ==============================================================================

# ---- 0. Setup ------------------------------------------------------------------

required_pkgs <- c("readxl", "dplyr", "stringr", "purrr", "tidyr", "here")
missing_pkgs  <- setdiff(required_pkgs, rownames(installed.packages()))
if (length(missing_pkgs) > 0) install.packages(missing_pkgs)

library(readxl)
library(dplyr)
library(stringr)
library(purrr)
library(tidyr)
library(here)

# ---- 1. Define file paths and target categories --------------------------------

data_folder <- here("data", "cfoi_rate")

if (!dir.exists(data_folder)) {
  stop(
    "Data folder not found at ", data_folder,
    ". Make sure the repo's data/cfoi_rate folder (with raw BLS .xlsx files) ",
    "was downloaded/cloned correctly, and that you've opened the .Rproj file ",
    "for this repo so the working directory is set correctly."
  )
}

# Industries/occupations to extract from each year's BLS table
wanted_rows <- c(
  "Total",
  "Fish and seafood merchant wholesalers",
  "Aquaculture",
  "Agriculture, forestry, fishing and hunting",
  "Crop production",
  "Animal production and aquaculture",
  "Animal production",
  "Logging",
  "Fishing, hunting, and trapping",
  "Support activities for agriculture and forestry",
  "Farming, fishing, and forestry occupations",
  "Miscellaneous agricultural workers",
  "Fishing and hunting workers",
  "Logging workers"
)

# ---- 2. Function to extract fatal injury rate table from one year's file -------

get_bls_rate <- function(file_path) {
  year <- str_extract(basename(file_path), "\\d{4}")
  message("\nProcessing year: ", year)

  tryCatch({
    sheets <- excel_sheets(file_path)
    result <- NULL

    for (sheet in sheets) {

      df_raw <- read_excel(file_path, sheet = sheet, col_names = FALSE)

      header_row <- which(apply(df_raw, 1, function(row) {
        any(str_detect(as.character(row), regex("Fatal injury rate", ignore_case = TRUE)))
      }))

      if (length(header_row) == 0) next
      header_row <- header_row[1]

      df <- read_excel(file_path, sheet = sheet, skip = header_row - 1)
      names(df) <- str_trim(names(df))

      row_col  <- names(df)[1]
      rate_col <- names(df)[str_detect(names(df), regex("Fatal injury rate", ignore_case = TRUE))][1]

      out <- df %>%
        mutate(row_value = str_trim(as.character(.data[[row_col]]))) %>%
        filter(row_value %in% wanted_rows) %>%
        select(
          Industry          = row_value,
          Fatal_injury_rate = all_of(rate_col)
        ) %>%
        mutate(
          Fatal_injury_rate = as.numeric(as.character(Fatal_injury_rate)),
          Year              = as.integer(year)
        )

      message("  Matched ", nrow(out), " rows")

      if (nrow(out) > 0) {
        result <- out
        break
      }
    }

    result

  }, error = function(e) {
    message("  Error processing ", basename(file_path), ": ", e$message)
    return(NULL)
  })
}

# ---- 3. Process all files and combine -------------------------------------------

files <- list.files(data_folder, pattern = "\\.xlsx$", full.names = TRUE)
message("Found ", length(files), " xlsx files")

all_data <- map_dfr(files, get_bls_rate)

if (is.null(all_data) || nrow(all_data) == 0) {
  stop("No data collected. Check that files exist and contain 'Fatal injury rate' columns.")
}

print(all_data, n = Inf)
all_data %>% count(Year) %>% print()

write.csv(
  all_data,
  file.path(data_folder, "bls_fatal_injury_rate_all_years.csv"),
  row.names = FALSE
)
message("\nSaved combined data to ", file.path(data_folder, "bls_fatal_injury_rate_all_years.csv"))

# ---- 4. Build wide-format summary table -----------------------------------------

wanted <- c(
  "Animal production",
  "Crop production",
  "Fishing, hunting, and trapping",
  "Total",
  "Logging"
)

table_wide <- all_data %>%
  mutate(Industry = case_when(
    Industry == "Animal production and aquaculture" ~ "Animal production",
    TRUE ~ Industry
  )) %>%
  filter(Industry %in% wanted) %>%
  select(Year, Industry, Fatal_injury_rate) %>%
  mutate(Year = as.integer(Year)) %>%
  pivot_wider(
    names_from  = Industry,
    values_from = Fatal_injury_rate
  ) %>%
  arrange(Year)

numeric_cols <- setdiff(names(table_wide), "Year")

average_row <- table_wide %>%
  summarise(across(all_of(numeric_cols), ~ mean(.x, na.rm = TRUE))) %>%
  mutate(Year = NA_integer_)

table_wide <- bind_rows(table_wide, average_row) %>%
  mutate(Year = ifelse(is.na(Year), "Average", as.character(Year)))

write.csv(
  table_wide,
  file.path(data_folder, "fatal_injury_rate_table.csv"),
  row.names = FALSE
)
message("Saved summary table to ", file.path(data_folder, "fatal_injury_rate_table.csv"))
