# 05_plot_gene_count.R
# Purpose: Compare gene counts (a proxy for genome size) across body sites,
#          counting each strain once and then each species once
# Input:   data/processed/catalog_taxonomy.csv
# Output:  figures/gene_count_by_site.png          (one point per strain)
#          figures/gene_count_by_site_species.png  (one point per species)

library(here)     # paths that work from the project root
library(dplyr)    # filter, mutate, summarise...
library(ggplot2)  # the plots

# ---- Load data ----

catalog <- read.csv(here("data", "processed", "catalog_taxonomy.csv"))

# Should match what 02_add_taxonomy.R saved. If not, re-run 01 and 02
stopifnot(nrow(catalog) == 1506)

# ---- Prepare strain-level data ----

gene_count_site <- catalog |>
  # Bacteria only: the 2 archaea are too few to form a distribution.
  # %in% instead of != so the 11 bacteria with domain = NA are kept
  filter(!(domain %in% "ARCHAEAL"), body_site != "unknown") |>
  # One row = one genome, so n() counts genomes per site
  group_by(body_site) |>
  mutate(site_total = n()) |>
  # Sites with 2 genomes or fewer say nothing useful, so they're out
  filter(site_total > 2) |>
  ungroup() |>
  # Flag the two species sequenced dozens of times, to color them in the plot
  mutate(highlight = if_else(
    species %in% c("Helicobacter pylori", "Propionibacterium acnes"),
    species, "Other species"
  ))

# 1180 bacterial genomes in 6 sites should survive
stopifnot(nrow(gene_count_site) == 1180)
stopifnot(n_distinct(gene_count_site$body_site) == 6)

# ---- Plot 1: one point per strain ----

gene_count_plot <- ggplot(
  gene_count_site,
  # Sites sorted by median gene count
  aes(x = gene_count, y = reorder(body_site, gene_count, median))
) +
  # outlier.shape = NA: outliers are already drawn by geom_jitter
  geom_boxplot(outlier.shape = NA) +
  # Fixed seed so the points land in the same place every run
  geom_jitter(
    aes(color = highlight),
    position = position_jitter(height = 0.2, seed = 1),
    alpha = 0.5
  ) +
  # Colorblind-friendly colors; "Other species" goes last in the legend
  scale_color_manual(
    values = c("Helicobacter pylori"     = "#D55E00",
               "Propionibacterium acnes" = "#0072B2",
               "Other species"           = "grey40"),
    breaks = c("Helicobacter pylori", "Propionibacterium acnes", "Other species")
  ) +
  labs(
    title   = "Gene count of HMP reference genomes by body site",
    x       = "Gene count",
    y       = NULL,
    color   = NULL,
    caption = "Reference genomes sequenced by the HMP, not relative abundance in the body"
  )

dir.create(here("figures"), showWarnings = FALSE)

ggsave(
  filename = here("figures", "gene_count_by_site.png"),
  plot     = gene_count_plot,
  width    = 9, height = 5, dpi = 300,
  device   = ragg::agg_png  # same PNG engine on every machine (see renv.lock)
)

stopifnot(file.exists(here("figures", "gene_count_by_site.png")))

# ---- Prepare species-level data ----

# Strains of the same species have almost the same gene count, so a species
# sequenced 60 times gets 60 "votes" in plot 1. Here each species counts once
gene_count_species <- gene_count_site |>
  # Genomes with no species name are treated as their own species
  mutate(unit = coalesce(species, organism)) |>
  group_by(body_site, unit) |>
  summarise(
    gene_count = median(gene_count),  # one value per species
    n_strains  = n(),                 # how many strains were collapsed
    .groups    = "drop"
  )

# 1180 genomes collapse into 752 species (428 were repeated strains)
stopifnot(nrow(gene_count_species) == 752)

# ---- Plot 2: one point per species ----

gene_count_species_plot <- ggplot(
  gene_count_species,
  aes(x = gene_count, y = reorder(body_site, gene_count, median))
) +
  geom_boxplot(outlier.shape = NA) +
  geom_jitter(position = position_jitter(height = 0.2, seed = 1), alpha = 0.3) +
  labs(
    title   = "Gene count of HMP reference genomes by body site (one point per species)",
    x       = "Median gene count per species",
    y       = NULL,
    caption = "Unnamed taxa are counted as separate species. Reference genomes sequenced by the HMP, not relative abundance in the body"
  )

ggsave(
  filename = here("figures", "gene_count_by_site_species.png"),
  plot     = gene_count_species_plot,
  width    = 9, height = 5, dpi = 300,
  device   = ragg::agg_png  # same PNG engine on every machine (see renv.lock)
)

stopifnot(file.exists(here("figures", "gene_count_by_site_species.png")))