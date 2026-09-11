# ==============================================================================
# Clean and Combine Non-Fatal Injury/Illness Incidence Rate Data
#
# Purpose: Extracts total recordable case incidence rates for selected
# industries from two BLS data sources:
#   (1) Older annual PDF tables (SOII summary tables)
#   (2) Newer annual Excel tables ("table-1-injury-and-illness-rates...")
# Combines both sources into one long-format dataset and a wide-format
# summary table.
#
# Data source: U.S. Bureau of Labor Statistics, Survey of Occupational
# Injuries and Illnesses (SOII) -
# https://www.bls.gov/iif/nonfatal-injuries-and-illnesses-tables/soii-summary-historical.htm
#
# Source files for this script are hosted on GitHub:
# https://github.com/dave-love/bls_injury_illness_fatality/tree/main/data/non_fatal_injury_rate
#
# NOTE: BLS did not publish a "Private industry" total in the 2015 table in
# a format this script could parse; that value (2.9) was added manually
# below based on BLS's published 2015 SOII summary release. See flagged
# section (Part 3) for details.
# ==============================================================================

# ---- 0. Setup -------------------------------------------------------------------

required_pkgs <- c("pdftools", "readxl", "dplyr", "stringr", "purrr",
                   "tidyr", "jsonlite")
missing_pkgs  <- setdiff(required_pkgs, rownames(installed.packages()))
if (length(missing_pkgs) > 0) install.packages(missing_pkgs)

library(pdftools)
library(readxl)
library(dplyr)
library(stringr)
library(purrr)
library(tidyr)
library(jsonlite)

# ---- 1. Define paths and shared reference tables ---------------------------------

gh_owner  <- "dave-love"
gh_repo   <- "bls_injury_illness_fatality"
gh_branch <- "main"
gh_path   <- "data/non_fatal_injury_rate"

output_folder <- "output"
if (!dir.exists(output_folder)) dir.create(output_folder)

target_naics <- c("3117", "111", "112", "1121", "1122", "1123", "1125", "113", "114")

naics_lookup <- tribble(
  ~NAICS,   ~Industry,
  "111",    "Crop production",
  "112",    "Animal production",
  "1121",   "Cattle ranching and farming",
  "1122",   "Hog and pig farming",
  "1123",   "Poultry and egg production",
  "1125",   "Aquaculture",
  "113",    "Forestry and logging",
  "114",    "Fishing, hunting and trapping",
  "3117",   "Seafood product preparation and packaging",
  "Total",  "Private industry"
)

# ---- 2. Helper functions for accessing files on GitHub ----------------------------

get_github_files <- function(owner, repo, path, branch = "main", pattern = NULL) {
  api_url <- sprintf(
    "https://api.github.com/repos/%s/%s/contents/%s?ref=%s",
    owner, repo, path, branch
  )
  
  file_list <- jsonlite::fromJSON(api_url)
  
  if (is.null(file_list$download_url)) {
    stop("No files found - check owner/repo/path/branch values.")
  }
  
  urls <- file_list$download_url
  names(urls) <- file_list$name
  
  if (!is.null(pattern)) {
    urls <- urls[str_detect(names(urls), pattern)]
  }
  
  urls
}

download_temp_file <- function(url, ext) {
  tmp <- tempfile(fileext = ext)
  download.file(url, tmp, mode = "wb", quiet = TRUE)
  tmp
}

# ==================================================================================
# PART 1: Extract data from older PDF tables
# ==================================================================================

# ---- 3. Helper functions for PDF parsing ------------------------------------------

extract_year <- function(text) {
  title_line <- str_split(text[1], "\n")[[1]] %>%
    str_trim() %>%
    .[nchar(.) > 0] %>%
    .[1]
  str_extract(title_line, "20\\d{2}|19\\d{2}")
}

detect_format <- function(text) {
  page1 <- text[1]
  if (str_detect(page1, regex("SIC\\s+code", ignore_case = TRUE))) return("SIC_SKIP")
  if (str_detect(page1, "TABLE SNR05"))                             return("SNR05")
  if (str_detect(page1, regex("NAICS", ignore_case = TRUE)))        return("TABLE_NAICS")
  return("UNKNOWN")
}

clean_line <- function(line) {
  line %>%
    str_replace_all("(?<=[a-zA-Z])[0-9]+(?=\\s|,|\\.|$)", "") %>%
    str_replace_all("\\.{2,}", " ") %>%
    str_replace_all("\\(\\s*\\d*\\s*\\)", "NA") %>%
    str_replace_all("(?<=\\s)–(?=\\s)|(?<=\\s)-(?=\\s)", "NA") %>%
    str_squish()
}

parse_line <- function(line, format_type) {
  cleaned <- clean_line(line)
  parts   <- str_split(cleaned, "\\s+")[[1]]
  
  naics_idx  <- which(parts %in% target_naics)
  is_private <- str_detect(cleaned, regex("^Private industry", ignore_case = TRUE))
  
  if (length(naics_idx) == 0 && !is_private) return(NULL)
  
  if (is_private) {
    first_num_idx <- which(str_detect(parts, "^\\d+\\.?\\d*$"))[1]
    if (is.na(first_num_idx)) return(NULL)
    
    industry <- "Private industry"
    naics    <- "Total"
    vals     <- parts[first_num_idx:length(parts)]
    
  } else {
    naics_idx <- naics_idx[1]
    industry  <- paste(parts[1:(naics_idx - 1)], collapse = " ")
    naics     <- parts[naics_idx]
    vals      <- parts[(naics_idx + 1):length(parts)]
  }
  
  if (format_type == "TABLE_NAICS") {
    tibble(
      Industry              = industry,
      NAICS                 = naics,
      Annual_avg_employment = if (length(vals) >= 1) vals[1] else NA_character_,
      Incidence_rate        = if (length(vals) >= 2) vals[2] else NA_character_,
      DAFW_JT_total         = if (length(vals) >= 3) vals[3] else NA_character_,
      Days_away_from_work   = if (length(vals) >= 4) vals[4] else NA_character_,
      Job_transfer          = if (length(vals) >= 5) vals[5] else NA_character_,
      Other_recordable      = if (length(vals) >= 6) vals[6] else NA_character_,
      Number_of_cases       = NA_character_
    )
  } else if (format_type == "SNR05") {
    tibble(
      Industry              = industry,
      NAICS                 = naics,
      Annual_avg_employment = NA_character_,
      Incidence_rate        = if (length(vals) >= 1) vals[1] else NA_character_,
      DAFW_JT_total         = NA_character_,
      Days_away_from_work   = NA_character_,
      Job_transfer          = NA_character_,
      Other_recordable      = NA_character_,
      Number_of_cases       = if (length(vals) >= 2) vals[2] else NA_character_
    )
  }
}

# ---- 4. Process one PDF -------------------------------------------------------------

process_pdf <- function(pdf_url) {
  pdf_name <- basename(pdf_url)
  message("Processing: ", pdf_name)
  
  tryCatch({
    pdf_path <- download_temp_file(pdf_url, ".pdf")
    
    text        <- pdf_text(pdf_path)
    year        <- extract_year(text)
    format_type <- detect_format(text)
    
    message("  Year: ", year, " | Format: ", format_type,
            " | Pages: ", length(text))
    
    if (format_type %in% c("SIC_SKIP", "UNKNOWN")) {
      message("  Skipping - ", format_type)
      return(NULL)
    }
    
    naics_pattern <- paste0(
      "(?<![0-9])(", paste(target_naics, collapse = "|"), ")(?![0-9])",
      "|^\\s*Private industry"
    )
    
    page_results <- imap_dfr(text, function(page, page_num) {
      lines <- str_split(page, "\n")[[1]] %>%
        str_trim() %>%
        .[nchar(.) > 0]
      
      matched_lines <- lines[str_detect(lines, naics_pattern)]
      if (length(matched_lines) == 0) return(NULL)
      
      message("  Page ", page_num, ": ", length(matched_lines), " matches")
      
      result <- map_dfr(matched_lines, parse_line, format_type = format_type)
      if (!is.null(result) && nrow(result) > 0) {
        result %>% mutate(Page = page_num)
      }
    })
    
    if (is.null(page_results) || nrow(page_results) == 0) {
      message("  No matching rows found")
      return(NULL)
    }
    
    page_results %>%
      mutate(
        Year        = as.integer(year),
        Source_file = pdf_name,
        Format      = format_type,
        across(
          c(Annual_avg_employment, Incidence_rate, DAFW_JT_total,
            Days_away_from_work, Job_transfer, Other_recordable,
            Number_of_cases),
          ~ suppressWarnings(as.numeric(na_if(str_trim(.), "NA")))
        )
      )
    
  }, error = function(e) {
    message("  Error: ", e$message)
    return(NULL)
  })
}

# ---- 5. Run across all PDFs ---------------------------------------------------------

pdf_urls <- get_github_files(gh_owner, gh_repo, gh_path,
                             branch = gh_branch, pattern = "\\.pdf$")
message("Found ", length(pdf_urls), " PDF files")

all_data <- map_dfr(pdf_urls, process_pdf)

# ---- 6. Clean industry names using NAICS lookup -------------------------------------

all_data_clean <- all_data %>%
  left_join(naics_lookup, by = "NAICS") %>%
  mutate(Industry = Industry.y) %>%
  select(-Industry.x, -Industry.y) %>%
  group_by(Year, NAICS) %>%
  slice(1) %>%
  ungroup() %>%
  arrange(Year, NAICS)

all_data_final <- all_data_clean %>%
  select(Industry, NAICS, Incidence_rate, Year)

# ---- 7. Summary checks: PDF data -----------------------------------------------------

message("--- PDF data: Rows per Year ---")
all_data_final %>% count(Year) %>% print(n = Inf)

message("--- PDF data: Rows per NAICS ---")
all_data_final %>% count(NAICS, Industry) %>% print(n = Inf)

message("--- PDF data: Private industry total check ---")
all_data_final %>% filter(NAICS == "Total") %>% print(n = Inf)

message("--- PDF data: Missing Incidence_rate ---")
all_data_final %>% filter(is.na(Incidence_rate)) %>% print(n = Inf)

# ==================================================================================
# PART 2: Extract data from newer Excel tables
# ==================================================================================

# ---- 8. Function to extract data from one Excel file --------------------------------

get_excel_data <- function(excel_url) {
  excel_name <- basename(excel_url)
  message("Processing: ", excel_name)
  
  tryCatch({
    excel_path <- download_temp_file(excel_url, ".xlsx")
    
    year_from_file <- str_extract(excel_name, "\\d{4}")
    
    df_raw <- read_excel(excel_path, sheet = 1, col_names = FALSE, n_max = 3)
    title  <- as.character(df_raw[[1]][1])
    year   <- str_extract(title, "20\\d{2}|19\\d{2}")
    if (is.na(year)) year <- year_from_file
    message("  Year: ", year)
    
    df <- read_excel(excel_path, sheet = 1, skip = 2)
    names(df) <- str_trim(names(df))
    
    industry_col <- names(df)[1]
    naics_col    <- names(df)[2]
    rate_col     <- names(df)[str_detect(names(df), regex("total.*record|incidence|^total",
                                                          ignore_case = TRUE))][1]
    message("  Rate column: ", rate_col)
    
    out <- df %>%
      rename(
        Industry_raw   = all_of(industry_col),
        NAICS          = all_of(naics_col),
        Incidence_rate = all_of(rate_col)
      ) %>%
      mutate(
        NAICS          = str_trim(as.character(NAICS)),
        Incidence_rate = suppressWarnings(as.numeric(as.character(Incidence_rate))),
        Industry_raw   = str_remove_all(
          str_trim(as.character(Industry_raw)),
          "(?<=[a-zA-Z])[0-9,]+(?=\\s|$)"
        )
      ) %>%
      filter(
        NAICS %in% target_naics |
          str_detect(Industry_raw, regex("^Private industry", ignore_case = TRUE))
      ) %>%
      mutate(
        NAICS = if_else(
          str_detect(Industry_raw, regex("^Private industry", ignore_case = TRUE)),
          "Total",
          NAICS
        )
      ) %>%
      left_join(naics_lookup, by = "NAICS") %>%
      select(Industry, NAICS, Incidence_rate) %>%
      mutate(Year = as.integer(year))
    
    message("  Matched ", nrow(out), " rows")
    out
    
  }, error = function(e) {
    message("  Error: ", e$message)
    return(NULL)
  })
}

# ---- 9. Run across all Excel files --------------------------------------------------

excel_urls <- get_github_files(
  gh_owner, gh_repo, gh_path,
  branch = gh_branch,
  pattern = "table-1-injury-and-illness-rates.*\\.xlsx$"
)
message("Found ", length(excel_urls), " excel files")

all_excel_data <- map_dfr(excel_urls, get_excel_data)

# ---- 10. Summary checks: Excel data --------------------------------------------------

message("--- Excel data: Rows per Year ---")
all_excel_data %>% count(Year) %>% print(n = Inf)

message("--- Excel data: Rows per NAICS ---")
all_excel_data %>% count(NAICS, Industry) %>% print(n = Inf)

message("--- Excel data: Private industry total check ---")
all_excel_data %>% filter(NAICS == "Total") %>% print(n = Inf)

message("--- Excel data: Missing Incidence_rate ---")
all_excel_data %>% filter(is.na(Incidence_rate)) %>% print(n = Inf)

# ==================================================================================
# PART 3: Combine PDF and Excel datasets
# ==================================================================================

all_combined <- bind_rows(all_data_final, all_excel_data) %>%
  arrange(Year, NAICS) %>%
  # BLS did not publish a "Private industry" total in a parseable format for
  # 2015; this value (2.9) was added manually based on BLS's published 2015
  # SOII summary release. See top-of-script note.
  add_row(
    Industry       = "Private industry",
    NAICS          = "Total",
    Incidence_rate = 2.9,
    Year           = 2015
  ) %>%
  arrange(Year, NAICS)

message("--- Combined rows per Year ---")
all_combined %>% count(Year) %>% print(n = Inf)

message("--- Combined rows per NAICS ---")
all_combined %>% count(NAICS, Industry) %>% print(n = Inf)

write.csv(
  all_combined,
  file.path(output_folder, "bls_injury_illness_all_years.csv"),
  row.names = FALSE
)
message("Saved to ", file.path(output_folder, "bls_injury_illness_all_years.csv"))

# ==================================================================================
# PART 4: Build wide-format summary table
# ==================================================================================

wanted <- c(
  "Aquaculture",
  "Animal production",
  "Crop production",
  "Fishing, hunting and trapping",
  "Private industry",
  "Forestry and logging"
)

table_wide <- all_combined %>%
  filter(Industry %in% wanted) %>%
  mutate(Industry = case_when(
    Industry == "Private industry"     ~ "Total",
    Industry == "Forestry and logging" ~ "Logging",
    TRUE ~ Industry
  )) %>%
  select(Year, Industry, Incidence_rate) %>%
  mutate(Year = as.integer(Year)) %>%
  pivot_wider(
    names_from  = Industry,
    values_from = Incidence_rate
  ) %>%
  arrange(Year)

numeric_cols <- setdiff(names(table_wide), "Year")

average_row <- table_wide %>%
  summarise(across(all_of(numeric_cols), ~ mean(.x, na.rm = TRUE))) %>%
  mutate(Year = NA_integer_)

table_wide <- bind_rows(table_wide, average_row) %>%
  mutate(Year = ifelse(is.na(Year), "Average", as.character(Year)))

print(table_wide)

write.csv(
  table_wide,
  file.path(output_folder, "injury_illness_incidence_rate_table.csv"),
  row.names = FALSE
)
message("Saved to ", file.path(output_folder, "injury_illness_incidence_rate_table.csv"))