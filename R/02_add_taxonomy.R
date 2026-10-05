# 02_add_taxonomy.R
# Purpose: Add genus and species columns derived from organism names
# Input:   data/processed/catalog_clean.csv
# Output:  data/processed/catalog_taxonomy.csv

library(here)     # project-relative paths
library(dplyr)      # mutate, if_else
library(stringr)      # word, str_detect

# ---- Load clean data ----

catalog <- read.csv(here("data", "processed", "catalog_clean.csv"))

# Contract with 01_clean.R: if this fails, re-run the cleaning step first
stopifnot(nrow(catalog) == 1506)

# ---- Genus ----
catalog <- catalog |>
  mutate(
    genus = word(organism, 1),
    # Names ending in -aceae (family), -ales (order) or -etes (phylum) are not genera:
    # e.g. "Lachnospiraceae bacterium", "Bacteroidetes oral taxon 274"
    genus = if_else(str_detect(genus, "(aceae|ales|etes)$"), NA, genus))

sum(is.na(catalog$genus))
catalog |> filter(is.na(genus)) |> head(10)

# 36 organisms are only classified above genus level (family/order/phylum)
stopifnot(sum(is.na(catalog$genus)) == 36)


# ---- Species ----

# Second words that mark an unnamed species rather than a real epithet
# ("oral" comes from HMP names like "<genus> oral taxon 274")
unnamed_markers <- c("sp.", "bacterium", "genomosp.", "oral")

catalog <- catalog |>
  mutate(
    # Specific epithet = second word of the organism name
    epithet = word(organism, 2),
    # Species is only defined when both genus and epithet are real names
    species = if_else(
      is.na(genus) | # case 1: no genus
        is.na(epithet) | # case 2: single-word na,e
        epithet %in% unnamed_markers, # case 3: "sp", "bacterium", ...
      NA,
      paste(genus, epithet)
    )
  ) |>
  select(-epithet)  # helper column, not needed downstream

# 290 organisms have no formal species name
stopifnot(sum(is.na(catalog$species)) == 290)

# ---- Save and verify ----
write.csv(catalog, here("data", "processed","catalog_taxonomy.csv"), row.names = FALSE)

# Re-read the saved file to confirm nothing changed on the way to disk
check <- read.csv(here("data", "processed", "catalog_taxonomy.csv"))
stopifnot(isTRUE(all.equal(catalog, check)))
