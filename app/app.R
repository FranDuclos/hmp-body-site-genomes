# app.R
# Purpose: Interactive map of the HMP reference genome catalog. Click a body
#          site on the silhouette to list the genomes isolated there
# Input:   data/catalog_app.csv (written by R/06_export_app_data.R)
# Run:     shiny::runApp("app") from the project root

library(shiny)  # the web app
library(bslib)  # layout and theme
library(DT)     # interactive table (search, sort, pages)

# ---- Data -------------------------------------------------------------------

# Shiny runs from inside app/, so this path is relative to this folder
catalog <- read.csv("data/catalog_app.csv")

# Readable names for each body site (the data uses snake_case)
site_labels <- c(
  gastrointestinal_tract = "Gastrointestinal tract",
  oral                   = "Oral cavity",
  urogenital_tract       = "Urogenital tract",
  skin                   = "Skin",
  airways                = "Airways",
  blood                  = "Blood",
  nose                   = "Nose",
  heart                  = "Heart",
  liver                  = "Liver",
  lymph_nodes            = "Lymph nodes",
  unknown                = "Unknown site"
)

# Genomes per site, to show next to each site name
site_counts <- table(catalog$body_site)

# Sites with this many genomes or fewer get a "too few data" warning
few_genomes <- 2

# ---- Silhouette -------------------------------------------------------------

# One color per body site (colorblind-friendly). The same color is used for
# the shape on the body and for the dot on its button
site_colors <- c(
  gastrointestinal_tract = "#009E73",  # green
  oral                   = "#CC79A7",  # pink
  urogenital_tract       = "#D9A400",  # mustard
  skin                   = "#E3C9AE",  # beige
  airways                = "#56B4E9",  # sky blue
  blood                  = "#A50F15",  # dark red
  nose                   = "#E69F00",  # orange
  heart                  = "#D55E00",  # vermilion
  liver                  = "#8C510A",  # brown
  lymph_nodes            = "#0072B2",  # blue
  unknown                = "#9CA3AF"   # grey (button only)
)

# Hand-drawn SVG. Every clickable shape has a data-site attribute with the
# body_site value it stands for; the JavaScript below sends it to the server.
# The body itself (head, torso, limbs) stands for the skin.
# Shapes with class "line" are drawn as strokes (bronchi, intestines, vessels)
silhouette <- HTML('
<svg viewBox="0 0 200 430" class="silhouette" role="img"
     aria-label="Human silhouette with clickable body sites">

  <g class="site body" data-site="skin">
    <title>Skin</title>
    <circle cx="100" cy="40" r="25"/>
    <rect x="90" y="60" width="20" height="20" rx="4"/>
    <path d="M58 92 Q100 76 142 92 L146 172 Q142 212 134 240 L66 240 Q58 212 54 172 Z"/>
    <path class="limb" d="M62 96 L46 152 L38 222"/>
    <path class="limb" d="M138 96 L154 152 L162 222"/>
    <path class="limb leg" d="M84 236 L82 412"/>
    <path class="limb leg" d="M116 236 L118 412"/>
  </g>

  <g class="site organ" data-site="nose">
    <title>Nose</title>
    <path d="M100 34 L95 48 Q100 51 105 48 Z"/>
  </g>

  <g class="site organ" data-site="oral">
    <title>Oral cavity</title>
    <path d="M90 56 Q95 52 100 54 Q105 52 110 56 Q100 64 90 56 Z"/>
  </g>

  <g class="site organ" data-site="airways">
    <title>Airways</title>
    <rect x="98" y="78" width="4" height="22" rx="2"/>
    <path class="line" d="M100 98 L91 108 M100 98 L109 108"/>
    <path d="M88 100 C74 102 68 120 70 142 C71 150 80 151 90 145 C93 130 93 112 88 100 Z"/>
    <path d="M112 100 C126 102 132 120 130 142 C129 150 120 151 110 145 C107 130 107 112 112 100 Z"/>
  </g>

  <g class="site organ" data-site="heart">
    <title>Heart</title>
    <path d="M103 121 c-3 -5 -11 -2 -9 4 c1 4 5 7 9 10 c4 -3 9 -6 9 -10 c2 -6 -6 -9 -9 -4 z"/>
  </g>

  <g class="site organ" data-site="lymph_nodes">
    <title>Lymph nodes</title>
    <ellipse cx="89" cy="72" rx="3.5" ry="2.5"/>
    <ellipse cx="111" cy="72" rx="3.5" ry="2.5"/>
    <ellipse cx="66" cy="104" rx="3.5" ry="2.5"/>
    <ellipse cx="134" cy="104" rx="3.5" ry="2.5"/>
    <ellipse cx="80" cy="238" rx="3.5" ry="2.5"/>
    <ellipse cx="120" cy="238" rx="3.5" ry="2.5"/>
  </g>

  <g class="site organ" data-site="liver">
    <title>Liver</title>
    <path d="M68 153 C70 146 92 145 104 150 C100 158 86 166 72 165 C67 163 66 157 68 153 Z"/>
  </g>

  <g class="site organ" data-site="gastrointestinal_tract">
    <title>Gastrointestinal tract</title>
    <path d="M112 150 C122 146 132 152 128 162 C124 170 112 168 108 162 C106 156 108 152 112 150 Z"/>
    <path class="line thick" d="M80 212 L80 180 Q80 174 86 174 L116 174 Q122 174 122 180 L122 212"/>
    <path class="line" d="M88 184 Q100 180 112 184 Q116 190 104 192 Q90 194 92 199 Q96 205 110 203 Q115 207 106 210 Q96 212 90 208"/>
  </g>

  <g class="site organ" data-site="urogenital_tract">
    <title>Urogenital tract</title>
    <path d="M89 221 Q100 213 111 221 Q113 231 100 236 Q87 231 89 221 Z"/>
  </g>

  <g class="site organ" data-site="blood">
    <title>Blood</title>
    <path class="line" d="M141 102 L153 152 L160 214"/>
    <path class="line" d="M59 102 L47 152 L40 214"/>
    <path d="M163 158 c0 0 -7 9 -7 14 a7 7 0 0 0 14 0 c0 -5 -7 -14 -7 -14 z"/>
  </g>
</svg>')

# One button per site, below the silhouette: shows the counts, works on
# phones (where small shapes are hard to tap) and holds "Unknown site"
site_buttons <- tags$div(
  class = "site-list",
  lapply(names(site_labels), function(site) {
    tags$button(
      type = "button",
      class = "site site-btn",
      `data-site` = site,
      tags$span(class = "dot"),
      site_labels[[site]],
      tags$span(class = "count", site_counts[[site]])
    )
  })
)

# ---- Look and feel ----------------------------------------------------------

# Each site gets its color as a CSS variable (--c), used by its shape and dot
color_rules <- paste0(
  sprintf('[data-site="%s"] { --c: %s; }', names(site_colors), site_colors),
  collapse = "\n"
)

css <- paste(color_rules, "
  .silhouette { width: 100%; max-width: 240px; display: block; margin: 0 auto; }
  .silhouette .site { cursor: pointer; transition: opacity 0.15s; }

  /* Body (skin): filled shapes plus thick strokes for the limbs */
  .silhouette .body > * { fill: var(--c); stroke: var(--c); }
  .silhouette .body .limb { fill: none; stroke-width: 18; stroke-linecap: round; }
  .silhouette .body .leg { stroke-width: 24; }

  /* Organs: filled shapes, and strokes for the 'line' parts */
  .silhouette .organ > * { fill: var(--c); stroke: #fff; stroke-width: 1; }
  .silhouette .organ .line {
    fill: none; stroke: var(--c); stroke-width: 3;
    stroke-linecap: round; stroke-linejoin: round;
  }
  .silhouette .organ .line.thick { stroke-width: 6; }

  /* Hover: slightly darker */
  .silhouette .site:hover { filter: brightness(0.88); }

  /* Once a site is picked, the others fade so it stands out */
  .silhouette.has-selection .organ:not(.selected) { opacity: 0.3; }
  .silhouette.has-selection .body:not(.selected) > * { fill: #efe6dc; stroke: #efe6dc; }
  .silhouette.has-selection .body:not(.selected) .limb { fill: none; }
  .silhouette .organ.selected > *:not(.line) { stroke: #1f2937; stroke-width: 1.2; }

  /* Buttons */
  .site-list { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 16px; }
  .site-btn {
    border: 1px solid #d0d4da; background: #fff; border-radius: 999px;
    padding: 3px 10px; font-size: 0.85rem; color: #333;
  }
  .site-btn:hover { border-color: var(--c); }
  .site-btn .dot {
    display: inline-block; width: 9px; height: 9px; border-radius: 50%;
    background: var(--c); margin-right: 6px;
  }
  .site-btn.selected { background: #1f2937; border-color: #1f2937; color: #fff; }
  .site-btn .count { opacity: 0.65; margin-left: 4px; }

  .caveat { font-size: 0.8rem; color: #6b7280; }
")

# Clicking any element with data-site sends its value to input$site and
# highlights every element (shape and button) of that same site
js <- "
  $(document).on('click', '.site', function(e) {
    e.stopPropagation();
    var site = $(this).data('site');
    $('.site').removeClass('selected');
    $('.site[data-site=\"' + site + '\"]').addClass('selected');
    $('.silhouette').addClass('has-selection');
    Shiny.setInputValue('site', site);
  });
"

# ---- UI ---------------------------------------------------------------------

ui <- page_fillable(
  title = "HMP body-site genomes",
  theme = bs_theme(version = 5, primary = "#2f6fae"),
  tags$head(tags$style(HTML(css)), tags$script(HTML(js))),

  h3("Which genomes did the Human Microbiome Project sequence at each body site?"),

  layout_columns(
    col_widths = breakpoints(sm = 12, lg = c(4, 8)),

    card(
      card_header("Click a body site"),
      silhouette,
      site_buttons
    ),

    card(
      card_header(uiOutput("site_title")),
      uiOutput("site_note"),
      DTOutput("table"),
      p(
        class = "caveat",
        "Reference genomes sequenced by the HMP, not abundance in the body. ",
        "Links open the NCBI BioProject of each genome."
      )
    )
  )
)

# ---- Server -----------------------------------------------------------------

server <- function(input, output, session) {

  # Rows for the selected site; before any click, all genomes are shown
  selected <- reactive({
    if (is.null(input$site)) catalog else catalog[catalog$body_site == input$site, ]
  })

  output$site_title <- renderUI({
    name <- if (is.null(input$site)) "All body sites" else site_labels[[input$site]]
    n    <- nrow(selected())
    tagList(strong(name), sprintf(" — %d genome%s", n, if (n == 1) "" else "s"))
  })

  # Notes for sites that need context: no recorded site, normally sterile
  # sites (strains there come from infections) and sites with very few genomes
  output$site_note <- renderUI({
    req(input$site)
    n     <- nrow(selected())
    notes <- list()

    if (input$site == "unknown") {
      notes <- c(notes, list(div(class = "alert alert-secondary py-2",
        "The catalog does not record where these strains were isolated.")))
    }
    if (input$site %in% c("blood", "heart")) {
      notes <- c(notes, list(div(class = "alert alert-info py-2",
        "Blood and heart are normally sterile: these strains come mostly from ",
        "infections (e.g. bacteremia, endocarditis), not from a resident microbiome.")))
    }
    if (input$site != "unknown" && n <= few_genomes) {
      notes <- c(notes, list(div(class = "alert alert-warning py-2",
        sprintf("Only %d genome%s: too few to describe this site.",
                n, if (n == 1) "" else "s"))))
    }
    tagList(notes)
  })

  output$table <- renderDT({
    rows <- selected()

    # Link to NCBI: the project ID opens its BioProject page
    ncbi_link <- sprintf(
      '<a href="https://www.ncbi.nlm.nih.gov/bioproject/%d" target="_blank" rel="noopener">PRJNA%d</a>',
      rows$ncbi_project_id, rows$ncbi_project_id
    )

    shown <- data.frame(
      Organism     = rows$organism,
      Genus        = rows$genus,
      Species      = rows$species,
      `Gene count` = rows$gene_count,
      NCBI         = ncbi_link,
      check.names  = FALSE
    )

    # With no site selected, add a column saying where each genome is from
    if (is.null(input$site)) {
      shown <- cbind(`Body site` = unname(site_labels[rows$body_site]), shown)
    }

    datatable(
      shown,
      rownames = FALSE,
      # Only the NCBI column holds HTML; everything else is escaped as text
      escape   = setdiff(names(shown), "NCBI"),
      # f = search box, t = table, i = "showing x of y", p = pages
      options  = list(pageLength = 15, order = list(), scrollX = TRUE, dom = "ftip")
    )
  })
}

shinyApp(ui, server)
