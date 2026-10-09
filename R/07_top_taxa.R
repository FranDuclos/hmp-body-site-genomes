# 07_top_taxa.R
# Purpose: Top 10 genera and species of each body site, as a share of its
#          genomes, for the "Top 10" chart of the Shiny app
# Input:   app/data/catalog_app.csv (written by 06_export_app_data.R)
# Output:  app/data/top_taxa.csv
#
# How this differs from the figures in 03 and 04 (on purpose):
# the figures summarize, so they drop small sites, "unknown" and genomes with
# no genus/species. The app explores, so here every site is kept, plus an
# "all" row for the whole catalog, and genomes with no name are counted as
# their own group, so each site always adds up to 100%

library(here)   # paths that work from the project root
library(dplyr)  # mutate, count, arrange, group_by...

# ---- Load data --------------------------------------------------------------

catalog <- read.csv(here("app", "data", "catalog_app.csv"))

# Should match what 06_export_app_data.R saved. If not, re-run main.R
stopifnot(nrow(catalog) == 1506)

# ---- Add an "all" site ------------------------------------------------------

# A copy of the whole table labeled "all", stacked under the original.
# This way one grouped calculation gives the top 10 per site AND overall
catalog_all <- bind_rows(
  catalog,
  catalog |> mutate(body_site = "all")
)

stopifnot(nrow(catalog_all) == 2 * 1506)

# ---- One row per genome and level -------------------------------------------

# Genus and species are ranked the same way, so they go in one long table:
# each genome appears twice, once with level = "genus" and once with "species"
long <- bind_rows(
  catalog_all |> transmute(body_site, level = "genus",   name = genus),
  catalog_all |> transmute(body_site, level = "species", name = species)
)

# ---- Rank and group ---------------------------------------------------------

top_taxa <- long |>
  # Genomes with no genus/species get a group name instead of NA
  mutate(
    no_name = is.na(name),
    name    = case_when(
      no_name & level == "genus"   ~ "No genus assigned",
      no_name & level == "species" ~ "No species name",
      .default = name
    )
  ) |>
  count(body_site, level, name, no_name) |>
  group_by(body_site, level) |>
  # Rank named taxa by count; ties are broken alphabetically so results never
  # change. The "no name" group stays out of the ranking
  arrange(no_name, desc(n), name, .by_group = TRUE) |>
  mutate(rank = if_else(no_name, NA, row_number())) |>
  # Named taxa outside the top 10 become one "Other" group
  mutate(
    group = no_name | rank > 10,
    name  = case_when(
      !no_name & rank > 10 & level == "genus"   ~ "Other genera",
      !no_name & rank > 10 & level == "species" ~ "Other species",
      .default = name
    )
  ) |>
  # Add up the "Other" rows, then turn counts into shares of the site
  group_by(body_site, level, name, group) |>
  summarise(n = sum(n), rank = min(rank), .groups = "drop") |>
  group_by(body_site, level) |>
  mutate(share = 100 * n / sum(n)) |>
  # Order: top 10 by rank, then "Other", then "No ... name"
  arrange(body_site, level, group, rank, .by_group = FALSE) |>
  ungroup() |>
  select(body_site, level, name, n, share, group)

# ---- Checks -----------------------------------------------------------------

# 11 body sites + "all", each with a genus and a species ranking
stopifnot(n_distinct(paste(top_taxa$body_site, top_taxa$level)) == 12 * 2)

# Every site still accounts for all its genomes, and shares add up to 100%
totals <- top_taxa |>
  group_by(body_site, level) |>
  summarise(n = sum(n), share = sum(share), .groups = "drop")
stopifnot(all(abs(totals$share - 100) < 1e-9))
stopifnot(all(totals$n[totals$body_site == "all"] == 1506))

# Never more than 10 named taxa per site
stopifnot(all(table(paste(top_taxa$body_site, top_taxa$level)[!top_taxa$group]) <= 10))

# ---- Save -------------------------------------------------------------------

# Tracked by Git, like catalog_app.csv: the published app needs it
write.csv(top_taxa, here("app", "data", "top_taxa.csv"), row.names = FALSE)

check <- read.csv(here("app", "data", "top_taxa.csv"))
stopifnot(isTRUE(all.equal(as.data.frame(top_taxa), check)))
