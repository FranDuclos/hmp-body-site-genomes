# main.R
# Purpose: Run the full analysis pipeline, from raw data to figures
# Usage:   source("main.R") from the project root, or open it and press Ctrl+Shift+S
# Output:  data/processed/*.csv and figures/*.png

library(here)  # paths that work from the project root

# ---- Run pipeline -----------------------------------------------------------

source(here("R", "01_clean.R"))
source(here("R", "02_add_taxonomy.R"))
source(here("R", "03_plot_genus.R"))
source(here("R", "04_plot_species.R"))
source(here("R", "05_plot_gene_count.R"))
source(here("R", "06_export_app_data.R"))

message("Pipeline finished: figures saved in figures/")
