library(here)
library(dplyr)
library(stringr)
library(ggplot2)
library(forcats)


catalogo_crudo <- read.csv(here("datos", "project_catalog.csv"), na.strings = c("","NA"))

stopifnot(nrow(catalogo_crudo) > 0)
stopifnot(sum(is.na(catalogo_crudo$Domain)) == 203)

summary(catalogo_crudo)
catalogo <- catalogo_crudo |>
  select(organismo = "Organism.Name","Domain","NCBI.Superkingdom","HMP.Isolation.Body.Site", "Gene.Count","NCBI.Project.ID") |>
  filter(!(is.na(Domain) & is.na(NCBI.Superkingdom))) |>   
  filter(Gene.Count > 0)      

stopifnot(nrow(catalogo$Domain) > 0)     # ¿qué tiene que ser cierto acá?

catalogo |> count(Domain, NCBI.Superkingdom)
summary(catalogo$Gene.Count)

catalogo <- catalogo |>
  filter(Gene.Count > 51) # Sacamos Prevotella pleuritidis

write.csv(catalogo, here("datos", "Catalogo-limpio.csv"), row.names = FALSE)

bd = read.csv(here("datos", "Catalogo-limpio.csv"))

catalogo <- catalogo |>
  mutate(genero = word(organismo, 1)) |>
  mutate(especie = paste(genero, word(organismo,2))) |>
  mutate(especie = if_else(word(organismo, 2) %in% c("sp.", "bacterium", "genomosp."), NA, especie)) |>
  mutate(genero = if_else(str_detect(genero, "(aceae|ales)$"), NA, genero))
  
# Genero por sitio:
genero_sitio <- catalogo |>
  filter(!is.na(genero)) |>
  count(HMP.Isolation.Body.Site, genero)

genero_sitio |>
  filter(HMP.Isolation.Body.Site == "skin") |>
  arrange(desc(n))

sitios_ok <- c("gastrointestinal_tract", "oral", "urogenital_tract",
               "skin", "airways", "blood")

genero_sitio |>
  filter(HMP.Isolation.Body.Site %in% sitios_ok) |>
  group_by(HMP.Isolation.Body.Site) |>
  mutate(rango = min_rank(desc(n)),
         genero = if_else(rango <= 10, genero, "Other")) |>
  ungroup() |>
  ggplot(aes(x = HMP.Isolation.Body.Site, y = n, fill = genero)) +
  geom_col(position = "fill") + 
  facet_wrap(~ HMP.Isolation.Body.Site, scales = "free")

  
# Especie sitio
especie_sitio <- catalogo |>
  filter(!is.na(especie)) |>
  count(HMP.Isolation.Body.Site, especie)

especie_sitio |>
  filter(HMP.Isolation.Body.Site %in% sitios_ok) |>
  group_by(HMP.Isolation.Body.Site) |>
  slice_max(n, n = 10, with_ties = FALSE) |>
  ungroup() |>
  ggplot(aes(x = n, y = especie)) +
  geom_col() +
  facet_wrap(~ HMP.Isolation.Body.Site, scales = "free_y")
