# 06_export_app_data.R
# Purpose: Export the table the Shiny app shows, inside the app folder,
#          so the app can be deployed on its own
# Input:   data/processed/catalog_taxonomy.csv
# Output:  app/data/catalog_app.csv

library(here)   # paths that work from the project root
library(dplyr)  # select, arrange

# ---- Load data --------------------------------------------------------------

catalog <- read.csv(here("data", "processed", "catalog_taxonomy.csv"))

# Should match what 02_add_taxonomy.R saved. If not, re-run 01 and 02
stopifnot(nrow(catalog) == 1506)

# ---- Keep only what the app needs -------------------------------------------

# All genomes go in, including "unknown" sites and sites with very few
# genomes: the app shows them with a warning instead of hiding them
catalog_app <- catalog |>
  select(body_site, organism, genus, species, gene_count, ncbi_project_id) |>
  arrange(body_site, organism)

# ---- Save -------------------------------------------------------------------

# This file IS tracked by Git (unlike data/processed/): when the app is
# published, only the app/ folder is uploaded, so its data must live there
dir.create(here("app", "data"), recursive = TRUE, showWarnings = FALSE)

write.csv(
  catalog_app,
  here("app", "data", "catalog_app.csv"),
  row.names = FALSE
)

check <- read.csv(here("app", "data", "catalog_app.csv"))
stopifnot(isTRUE(all.equal(catalog_app, check)))
