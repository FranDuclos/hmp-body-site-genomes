# 04_plot_species.R
# Purpose: Plot the top 10 species of HMP reference genomes in each body site,
#          keeping only species with at least 2 genomes in that site
# Input:   data/processed/catalog_taxonomy.csv
# Output:  figures/species_by_site.png

library(here)      # paths that work from the project root
library(dplyr)     # filter, count, mutate...
library(ggplot2)   # the plot
library(tidytext)  # reorder_within: sort bars inside each panel

# ---- Load data ----

catalog <- read.csv(here("data", "processed", "catalog_taxonomy.csv"))

# Should match what 02_add_taxonomy.R saved. If not, re-run 01 and 02
stopifnot(nrow(catalog) == 1506)

# ---- Count genomes per species and site ----

species_by_site <- catalog |>
  # Skip rows with no species and rows with no known body site
  filter(!is.na(species), body_site != "unknown") |>
  count(body_site, species) |>
  # Total genomes per site, to drop the tiny ones
  group_by(body_site) |>
  mutate(site_total = sum(n)) |>
  # Sites with 2 genomes or fewer say nothing useful, so they're out
  filter(site_total > 2) |>
  ungroup() |>
  # Species with a single genome would all tie at 1, and the "top 10" would
  # be decided alphabetically. Keep only species that actually repeat
  filter(n >= 2)

# 6 sites should survive: airways, blood, GI tract, oral, skin, urogenital
stopifnot(n_distinct(species_by_site$body_site) == 6)

# ---- Keep the top 10 per site ----

species_top10 <- species_by_site |>
  # Sort by count; ties are broken alphabetically so results never change
  arrange(body_site, desc(n), species) |>
  group_by(body_site) |>
  mutate(rank = row_number()) |>
  ungroup() |>
  # Some sites have fewer than 10 repeated species, so they show fewer bars
  filter(rank <= 10)

# ---- Plot ----

# One panel per site, horizontal bars (same idea as the genus plots)
species_plot <- ggplot(
  species_top10,
  # Sort bars from big to small inside each panel (not across all panels)
  aes(x = n, y = reorder_within(species, n, body_site))
) +
  geom_col() +
  facet_wrap(~ body_site, scales = "free_y") +
  scale_y_reordered() +  # cleans up the labels reorder_within messes with
  labs(
    title    = "Top 10 species of HMP reference genomes by body site",
    subtitle = "Only species with at least 2 genomes in that site",
    x        = "Number of genomes",
    y        = NULL,     # species names speak for themselves
    caption  = "Reference genomes sequenced by the HMP, not relative abundance in the body"
  )

# ---- Save ----

dir.create(here("figures"), showWarnings = FALSE)

# A bit wider than the genus plot: species names are longer
ggsave(
  filename = here("figures", "species_by_site.png"),
  plot     = species_plot,
  width    = 11, height = 8, dpi = 300
)

stopifnot(file.exists(here("figures", "species_by_site.png")))