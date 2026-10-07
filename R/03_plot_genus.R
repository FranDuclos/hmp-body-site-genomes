# 03_plot_genus.R
# Purpose: Plot the top 10 genera of HMP reference genomes in each body site,
#          with and without an "Other" bar for everything outside the top 10
# Input:   data/processed/catalog_taxonomy.csv
# Output:  figures/genus_by_site.png        (top 10 only)
#          figures/genus_by_site_other.png  (top 10 + "Other")

library(here)      # paths that work from the project root
library(dplyr)     # filter, count, mutate...
library(ggplot2)   # the plots
library(tidytext)  # reorder_within: sort bars inside each panel

# ---- Load data ----

catalog <- read.csv(here("data", "processed", "catalog_taxonomy.csv"))

# Should match what 02_add_taxonomy.R saved. If not, re-run 01 and 02
stopifnot(nrow(catalog) == 1506)

# ---- Count genomes per genus and site ----

genus_by_site <- catalog |>
  # Skip rows with no genus and rows with no known body site
  filter(!is.na(genus), body_site != "unknown") |>
  count(body_site, genus) |>
  # Total genomes per site, to drop the tiny ones
  group_by(body_site) |>
  mutate(site_total = sum(n)) |>
  # Sites with 2 genomes or fewer say nothing useful, so they're out
  filter(site_total > 2) |>
  ungroup()

# 6 sites should survive: airways, blood, GI tract, oral, skin, urogenital
stopifnot(n_distinct(genus_by_site$body_site) == 6)

# ---- Rank genera inside each site ----

# This ranked table is the base for both versions of the plot
genus_ranked <- genus_by_site |>
  # Sort by count; ties are broken alphabetically so results never change
  arrange(body_site, desc(n), genus) |>
  group_by(body_site) |>
  mutate(rank = row_number()) |>
  ungroup()

# Version 1: just the top 10
genus_top10 <- genus_ranked |>
  filter(rank <= 10)

# Version 2: top 10 + one "Other" bar with everything else
genus_other <- genus_ranked |>
  mutate(genus = if_else(rank <= 10, genus, "Other")) |>
  # Add up all the "Other" rows so each site has just one "Other" bar
  count(body_site, genus, wt = n)

# ---- Plots ----

# One panel per site. Each site has its own top 10, so a single color
# legend would be huge and unreadable. Horizontal bars fix that
genus_plot_top10 <- ggplot(
  genus_top10,
  # Sort bars from big to small inside each panel (not across all panels)
  aes(x = n, y = reorder_within(genus, n, body_site))
) +
  geom_col() +
  facet_wrap(~ body_site, scales = "free_y") +
  scale_y_reordered() +  # cleans up the labels reorder_within messes with
  labs(
    title   = "Top 10 genera of HMP reference genomes by body site",
    x       = "Number of genomes",
    y       = NULL,      # genus names speak for themselves
    caption = "Reference genomes sequenced by the HMP, not relative abundance in the body"
  )

# Same plot, but with the "Other" bar to show how much is left out
genus_plot_other <- ggplot(
  genus_other,
  aes(x = n, y = reorder_within(genus, n, body_site))
) +
  geom_col() +
  facet_wrap(~ body_site, scales = "free_y") +
  scale_y_reordered() +
  labs(
    title   = "Top 10 genera of HMP reference genomes by body site (rest as Other)",
    x       = "Number of genomes",
    y       = NULL,
    caption = "Reference genomes sequenced by the HMP, not relative abundance in the body"
  )

# ---- Save ----

dir.create(here("figures"), showWarnings = FALSE)

# Fixed size so the images look the same no matter your window size
ggsave(
  filename = here("figures", "genus_by_site.png"),
  plot     = genus_plot_top10,
  width    = 10, height = 7, dpi = 300
)

ggsave(
  filename = here("figures", "genus_by_site_other.png"),
  plot     = genus_plot_other,
  width    = 10, height = 7, dpi = 300
)

stopifnot(file.exists(here("figures", c("genus_by_site.png",
                                        "genus_by_site_other.png"))))