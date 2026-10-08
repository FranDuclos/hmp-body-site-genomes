# 01_clean.R
# Purpose: Read the raw HMP catalog, validate it, drop rows with missing
#          taxonomy or gene counts, and save the clean table
# Input:   data/raw/project_catalog.csv
# Output:  data/processed/catalog_clean.csv

library(here)   # paths that work from the project root
library(dplyr)  # select, filter

# ---- Load raw data ----------------------------------------------------------

# Empty cells and "Error!!!" (junk values in the raw file) are read as NA,
# so all missing values are handled the same way
catalog_raw <- read.csv(
  here("data", "raw", "project_catalog.csv"),
  na.strings = c("", "NA", "Error!!!")
)

# Sanity checks: the file loaded, and it's the same version explored
# originally (203 missing values in Domain)
stopifnot(nrow(catalog_raw) > 0)
stopifnot(sum(is.na(catalog_raw$Domain)) == 203)

# ---- Select and filter ------------------------------------------------------

catalog <- catalog_raw |>
  select(
    organism        = Organism.Name,
    domain          = Domain,
    superkingdom    = NCBI.Superkingdom,
    body_site       = HMP.Isolation.Body.Site,
    gene_count      = Gene.Count,
    ncbi_project_id = NCBI.Project.ID   # kept to build NCBI links later
  ) |>
  # Drop a row only if BOTH taxonomy fields are missing: requiring both
  # would throw away 112 valid bacteria that only have superkingdom
  filter(!(is.na(domain) & is.na(superkingdom))) |>
  # A gene count of 0 means "not reported", not a genome with no genes
  filter(gene_count > 0)

# Expected row count, double-checked with an independent Python run
stopifnot(nrow(catalog) == 1507)

# ---- Remove outliers --------------------------------------------------------

# Remove Prevotella pleuritidis F0068: only 51 genes vs. thousands expected
# for a free-living bacterium, likely an incomplete or mis-annotated record
catalog <- catalog |>
  filter(ncbi_project_id != 72901)

stopifnot(nrow(catalog) == 1506)

# ---- Save and verify --------------------------------------------------------

dir.create(here("data", "processed"), showWarnings = FALSE)

write.csv(
  catalog,
  here("data", "processed", "catalog_clean.csv"),
  row.names = FALSE
)

# Read the file back to make sure nothing changed on the way to disk
check <- read.csv(here("data", "processed", "catalog_clean.csv"))
stopifnot(isTRUE(all.equal(catalog, check)))