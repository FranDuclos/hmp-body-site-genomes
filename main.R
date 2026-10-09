# main.R
# Purpose: Run the full pipeline, from raw data to figures and app data
# Usage:   source("main.R") from the project root, or open it and press Ctrl+Shift+S
# Output:  data/processed/*.csv, figures/*.png and app/data/*.csv

library(here)  # paths that work from the project root

# ---- Run pipeline -----------------------------------------------------------

source(here("R", "01_clean.R"))
source(here("R", "02_add_taxonomy.R"))
source(here("R", "03_plot_genus.R"))
source(here("R", "04_plot_species.R"))
source(here("R", "05_plot_gene_count.R"))
source(here("R", "06_export_app_data.R"))
source(here("R", "07_top_taxa.R"))

message("Pipeline finished: figures in figures/, app data in app/data/")
