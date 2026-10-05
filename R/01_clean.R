# 01_clean.R
# Purpose: Read the raw HMP catalog, validate it, drop rows with missing
#          taxonomy or gene counts, and save the clean table.
# Input:   data/raw/project_catalog.csv
# Output:  data/processed/catalog_clean

library(here) # project-relative paths
library(dplyr) # select, filter

# ---- Low raw Data ----

# Empty cells are read as NA so missing values are hundled consistenly
catalog_raw <- read.csv(
  here("data", "raw", "project_catalog.csv"),
  na.strings = c("", "NA")
)

stopifnot(nrow(catalog_raw) > 0)
stopifnot(sum(is.na(catalog_raw$Domain)) == 203) # The version explored originally have 203 missing values in Domain

# ---- Select and filter ----

catalog <- catalog_raw |>
  select(
    organism        = Organism.Name,
    domain          = Domain,
    superkingdom    = NCBI.Superkingdom,
    body_site       = HMP.Isolation.Body.Site,
    gene_count             = Gene.Count,
    ncbi_project_id             = NCBI.Project.ID
  ) |>
  # Drop a row only if BOTH taxonomy fields are missing: requiring both
  # would discard 112 valid bacteria that only have superkingdom
  filter(!(is.na(domain) & is.na(superkingdom))) |>
  # A gene count of 0 means "not reported", not a genome with no genes
  filter(gene_count > 0)

# Expected row count.
stopifnot(nrow(catalog) == 1507)

#---- Remove outlier ----

catalog |> filter(gene_count <= 51)

# Remove Prevotella pleuritidis F0068: only 51 genes vs. thousands expected 
# for a free-living bacterium, likely an incomplete or mis-annotated record
catalog <- catalog |>
  filter(ncbi_project_id != 72901)

stopifnot(nrow(catalog) == 1506)

# ---- Save and verify ----
dir.create(here("data", "processed"), showWarnings = FALSE)

write.csv(catalog, here("data", "processed", "catalog_clean.csv"), row.names = FALSE)

check <- read.csv(here("data", "processed", "catalog_clean.csv"))
stopifnot(isTRUE(all.equal(catalog, check)))
