# BLS Occupational Injury, Illness, and Fatality Data

This repository contains R scripts and cleaned datasets on workplace injuries,
illnesses, and fatalities in U.S. industries, with a particular focus on
agriculture, forestry, fishing, and related sectors. All data are sourced
from the U.S. Bureau of Labor Statistics (BLS).


## Overview

This project combines two BLS data programs into a single, analysis-ready
set of long- and wide-format datasets:

1. **Non-fatal injury and illness incidence rates**, from the Survey of
   Occupational Injuries and Illnesses (SOII)
2. **Fatal occupational injury rates**, from the Census of Fatal
   Occupational Injuries (CFOI)

Both datasets are cleaned, standardized to consistent industry categories,
and combined across years into long-format CSVs, with wide-format summary
tables for selected industries of interest (agriculture, forestry, fishing,
and aquaculture).

## Data Sources

### Non-fatal injury and illness rates (SOII)

- **Source:** U.S. Bureau of Labor Statistics, Survey of Occupational
  Injuries and Illnesses
- **URL:** https://www.bls.gov/iif/nonfatal-injuries-and-illnesses-tables/soii-summary-historical.htm
- **Formats:** Older years are published as PDF summary tables; newer years
  are published as Excel tables ("table-1-injury-and-illness-rates...")
- **Measure used:** Total recordable case (TRC) incidence rate per 100
  full-time workers

### Fatal occupational injuries (CFOI)

- **Source:** U.S. Bureau of Labor Statistics, Census of Fatal Occupational
  Injuries
- **URL:** https://www.bls.gov/iif/fatal-injuries-tables.htm
- **Coverage:** 2006–2024
- **Format:** One Excel (.xlsx) file per year, as downloaded from BLS
- **Measure used:** Fatal injury rate per 100,000 full-time equivalent
  workers

## Repository structure
- bls_injury_illness_fatality/
- bls_injury_illness_fatality/data/
- bls_injury_illness_fatality/output/
- README.md

## Scripts

### `clean_nonfatal_injury_illness.R`

Extracts total recordable case incidence rates for selected industries from:

1. Older annual PDF tables (SOII summary tables)
2. Newer annual Excel tables ("table-1-injury-and-illness-rates...")

Combines both sources into:

- A long-format dataset (one row per industry × year)
- A wide-format summary table (one row per year, one column per industry)

Source files are read directly from this repository on GitHub via the
GitHub API, so the script can be run without needing local copies of the
raw BLS files.

### `clean_fatality_data.R`

Reads BLS Census of Fatal Occupational Injuries (CFOI) Excel files
(2006–2024, one file per year), and extracts fatal injury rates for a
broader set of industries and occupations relevant to this study
(defined in `wanted_rows`), including both industry-based categories
(e.g., "Crop production," "Logging") and occupation-based categories
(e.g., "Fishing and hunting workers," "Logging workers").

For each year's file, the script searches all sheets for one containing
a "Fatal injury rate" column, extracts matching rows, and standardizes
them into a consistent long-format structure. All years are then combined
into a single dataset, and a wide-format summary table is built for a
smaller subset of industries used in the manuscript's final tables and
figures (`wanted`), with an added "Average" row across all years.

> **Note:** Unlike the non-fatal script, this script currently reads
> input files from a local folder rather than directly from GitHub. See
> [Usage](#usage) for details.

## Output Files

| File | Description |
|---|---|
| `bls_injury_illness_all_years.csv` | Long-format non-fatal incidence rate data, all years, all matched industries |
| `injury_illness_incidence_rate_table.csv` | Wide-format non-fatal incidence rate summary table, selected industries, with an average row |
| `bls_fatal_injury_rate_all_years.csv` | Long-format fatal injury rate data, 2006–2024, all matched industries/occupations |
| `fatal_injury_rate_table.csv` | Wide-format fatal injury rate summary table, selected industries, with an average row |

### Industries covered

**Non-fatal injury/illness data** is filtered and standardized to the
following NAICS categories:

| NAICS | Industry |
|---|---|
| 111 | Crop production |
| 112 | Animal production |
| 1121 | Cattle ranching and farming |
| 1122 | Hog and pig farming |
| 1123 | Poultry and egg production |
| 1125 | Aquaculture |
| 113 | Forestry and logging |
| 114 | Fishing, hunting and trapping |
| 3117 | Seafood product preparation and packaging |
| Total | Private industry (all sectors) |

**Fatal injury rate data** is extracted for a broader list of
industry/occupation categories as published by BLS, including:

- Total (all industries)
- Agriculture, forestry, fishing and hunting
- Crop production
- Animal production / Animal production and aquaculture
- Aquaculture
- Logging
- Fishing, hunting, and trapping
- Farming, fishing, and forestry occupations
- Fishing and hunting workers
- Logging workers

The final wide-format summary table (`fatal_injury_rate_table.csv`) is
limited to a smaller subset used in the manuscript: **Animal production**,
**Crop production**, **Fishing, hunting, and trapping**, **Total**, and
**Logging**.

## Requirements

This project uses R (≥ 4.0 recommended) and the following packages:

```r
install.packages(c(
  "pdftools", "readxl", "dplyr", "stringr",
  "purrr", "tidyr", "jsonlite"
))
```
## Declaration of generative AI use:
Generative AI was used to assist in writing and debugging R code used to clean and prepare the datasets and tables as well as to develop the file structure for this GitHub repositories. All code was reviewed, tested, and verified by the authors, who take full responsibility for its accuracy and outputs.

## Contact for more information

Dave Love, PhD, MSPH  
Research Professor  
Johns Hopkins Center for a Livable Future  
Department of Environmental Health and Engineering  
Johns Hopkins Bloomberg School of Public Health  
dlove8@jhu.edu

