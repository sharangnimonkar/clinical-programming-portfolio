# Calling the packages needed
library(shiny)
library(shinydashboard)
library(DT)
library(plotly)
library(dplyr)
library(pharmaverseadam)

# ---------------------------------------------------------------------------
# Load ADaM data
# ---------------------------------------------------------------------------
adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

# ---------------------------------------------------------------------------
# Column resolution
#
# pharmaverseadam follows ADaM conventions, but variable availability shifts
# between package versions (AEBODSYS vs AESOC, TRTA vs TRT01A). Resolve once at
# startup so the app fails loudly at launch rather than silently in a reactive.
# ---------------------------------------------------------------------------
pick_col <- function(df, candidates, label) {
  hit <- candidates[candidates %in% names(df)]
  if (length(hit) == 0) {
    stop(sprintf("Could not find a %s variable. Looked for: %s",
                 label, paste(candidates, collapse = ", ")))
  }
  hit[1]
}

SOC_VAR <- pick_col(adae, c("AEBODSYS", "AESOC"), "system organ class")
TRT_AE  <- pick_col(adae, c("TRTA", "TRT01A", "TRTP", "TRT01P"), "AE treatment")
TRT_SL  <- pick_col(adsl, c("TRT01A", "TRT01P", "ACTARM", "ARM"), "ADSL treatment")

has <- function(df, v) v %in% names(df)

# ---------------------------------------------------------------------------
# Standardise to a common working frame
# ---------------------------------------------------------------------------
adsl_w <- adsl %>%
  transmute(
    USUBJID,
    TRT    = .data[[TRT_SL]],
    SAFFL  = if (has(adsl, "SAFFL"))  SAFFL  else "Y",
    AGE    = if (has(adsl, "AGE"))    AGE    else NA_real_,
    SEX    = if (has(adsl, "SEX"))    SEX    else NA_character_,
    SITEID = if (has(adsl, "SITEID")) as.character(SITEID) else NA_character_
  ) %>%
  filter(SAFFL == "Y")

adae_w <- adae %>%
  transmute(
    USUBJID,
    TRT     = .data[[TRT_AE]],
    AESOC   = .data[[SOC_VAR]],
    AEDECOD,
    AESEV   = if (has(adae, "AESEV"))   toupper(AESEV) else NA_character_,
    AEREL   = if (has(adae, "AEREL"))   AEREL          else NA_character_,
    AESER   = if (has(adae, "AESER"))   AESER          else NA_character_,
    TRTEMFL = if (has(adae, "TRTEMFL")) TRTEMFL        else "Y",
    ASTDY   = if (has(adae, "ASTDY"))   as.numeric(ASTDY) else NA_real_,
    AENDY   = if (has(adae, "AENDY"))   as.numeric(AENDY) else NA_real_
  ) %>%
  # keep only safety-population subjects so incidence denominators line up
  semi_join(adsl_w, by = "USUBJID")

trt_levels <- sort(unique(adsl_w$TRT))
soc_levels <- sort(unique(adae_w$AESOC))
sev_levels <- sort(unique(na.omit(adae_w$AESEV)))
sev_cols   <- c(MILD = "#00a65a", MODERATE = "#f39c12", SEVERE = "#dd4b39")

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
ui <- dashboardPage(
  dashboardHeader(title = "Safety Monitoring Dashboard"),
  
  dashboardSidebar(
    selectInput("trt", "Treatment Arm",
                choices = c("All", trt_levels), selected = "All"),
    selectInput("soc", "System Organ Class",
                choices = c("All", soc_levels), selected = "All"),
    checkboxGroupInput("sev", "Severity",
                       choices = sev_levels, selected = sev_levels),
    checkboxInput("teae_only", "Treatment-emergent only", value = TRUE),
    checkboxInput("serious_only", "Serious AEs only", value = FALSE),
    hr(),
    sidebarMenu(
      menuItem("Overview",         tabName = "overview", icon = icon("chart-bar")),
      menuItem("AE Listing",       tabName = "listing",  icon = icon("table")),
      menuItem("Subject Profile",  tabName = "timeline", icon = icon("user"))
    )
  ),
  
  dashboardBody(
    tabItems(
      tabItem(
        tabName = "overview",
        fluidRow(
          valueBoxOutput("box_subjects"),
          valueBoxOutput("box_ae_total"),
          valueBoxOutput("box_serious")
        ),
        fluidRow(
          box(title = "Top 10 Preferred Terms — Subject Incidence (%)",
              width = 6, status = "primary", solidHeader = TRUE,
              plotlyOutput("plot_pt", height = 420)),
          box(title = "Event Severity by Treatment Arm",
              width = 6, status = "primary", solidHeader = TRUE,
              plotlyOutput("plot_sev", height = 420))
        ),
        fluidRow(
          box(title = "AE Summary by System Organ Class",
              width = 12, status = "primary", solidHeader = TRUE,
              DTOutput("soc_table"))
        )
      ),
      
      tabItem(
        tabName = "listing",
        box(title = "Adverse Event Listing", width = 12,
            status = "primary", solidHeader = TRUE,
            DTOutput("ae_table"))
      ),
      
      tabItem(
        tabName = "timeline",
        box(title = "Subject AE Profile", width = 12,
            status = "primary", solidHeader = TRUE,
            selectInput("subj_id", "Select Subject (USUBJID)",
                        choices = sort(unique(adsl_w$USUBJID))),
            uiOutput("subj_header"),
            plotlyOutput("plot_subj_timeline", height = 380),
            DTOutput("subj_ae_table"))
      )
    )
  )
)
# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # Subjects in the selected arm — the incidence denominator
  filtered_subjects <- reactive({
    if (input$trt == "All") adsl_w else filter(adsl_w, TRT == input$trt)
  })
  
  filtered_ae <- reactive({
    df <- adae_w
    
    if (input$teae_only)    df <- filter(df, TRTEMFL == "Y")
    if (input$trt != "All") df <- filter(df, TRT == input$trt)
    if (input$soc != "All") df <- filter(df, AESOC == input$soc)
    if (input$serious_only) df <- filter(df, AESER == "Y")
    
    if (length(input$sev) > 0) {
      df <- filter(df, AESEV %in% input$sev)
    } else {
      df <- df[0, ]
    }
    df
  })
  
  # ---- Value boxes ----
  output$box_subjects <- renderValueBox({
    valueBox(nrow(filtered_subjects()), "Safety Population (N)",
             icon = icon("users"), color = "blue")
  })
  
  output$box_ae_total <- renderValueBox({
    valueBox(nrow(filtered_ae()), "AE Records",
             icon = icon("notes-medical"), color = "yellow")
  })
  
  output$box_serious <- renderValueBox({
    n <- sum(filtered_ae()$AESER == "Y", na.rm = TRUE)
    valueBox(n, "Serious AEs", icon = icon("exclamation-triangle"), color = "red")
  })
  
  # ---- Top PTs by subject incidence (not event count) ----
  output$plot_pt <- renderPlotly({
    denom <- nrow(filtered_subjects())
    validate(need(denom > 0, "No subjects in this selection."))
    
    df <- filtered_ae() %>%
      distinct(USUBJID, AEDECOD) %>%
      count(AEDECOD, name = "n_subj") %>%
      mutate(pct = round(100 * n_subj / denom, 1)) %>%
      arrange(desc(pct)) %>%
      head(10)
    
    validate(need(nrow(df) > 0, "No events match the current filters."))
    
    plot_ly(df, x = ~pct, y = ~reorder(AEDECOD, pct), type = "bar",
            orientation = "h",
            marker = list(color = "#3c8dbc"),
            hovertemplate = ~paste0(AEDECOD, "<br>", n_subj, "/", denom,
                                    " subjects (", pct, "%)<extra></extra>")) %>%
      layout(xaxis = list(title = "Subjects with event (%)"),
             yaxis = list(title = ""),
             margin = list(l = 10))
  })
  
  # ---- Severity by arm ----
  output$plot_sev <- renderPlotly({
    df <- filtered_ae() %>%
      filter(!is.na(AESEV)) %>%
      count(TRT, AESEV, name = "n")
    
    validate(need(nrow(df) > 0, "No events match the current filters."))
    
    plot_ly(df, x = ~TRT, y = ~n, color = ~AESEV, type = "bar",
            colors = sev_cols) %>%
      layout(barmode = "stack",
             xaxis = list(title = ""),
             yaxis = list(title = "Number of Events"),
             legend = list(orientation = "h", y = -0.25))
  })
  
  # ---- SOC summary table (subjects, incidence %, events) ----
  output$soc_table <- renderDT({
    denom <- nrow(filtered_subjects())
    validate(need(denom > 0, "No subjects in this selection."))
    
    events <- filtered_ae() %>% count(AESOC, name = "Events")
    subs   <- filtered_ae() %>%
      distinct(USUBJID, AESOC) %>%
      count(AESOC, name = "Subjects")
    
    subs %>%
      left_join(events, by = "AESOC") %>%
      mutate(`Incidence (%)` = round(100 * Subjects / denom, 1)) %>%
      arrange(desc(Subjects)) %>%
      select(`System Organ Class` = AESOC, Subjects, `Incidence (%)`, Events)
  }, options = list(pageLength = 10), rownames = FALSE)
  
  # ---- AE listing ----
  output$ae_table <- renderDT({
    filtered_ae() %>%
      select(USUBJID, TRT, AESOC, AEDECOD, AESEV, AEREL, AESER, ASTDY, AENDY) %>%
      arrange(USUBJID, ASTDY)
  }, filter = "top", options = list(pageLength = 15), rownames = FALSE)
  
  # ---- Subject profile ----
  subj_ae <- reactive({
    adae_w %>% filter(USUBJID == input$subj_id) %>% arrange(ASTDY)
  })
  
  output$subj_header <- renderUI({
    s <- adsl_w %>% filter(USUBJID == input$subj_id)
    validate(need(nrow(s) == 1, "Subject not in safety population."))
    tags$p(
      tags$strong("Arm: "), s$TRT,
      tags$strong("  |  Age: "), s$AGE,
      tags$strong("  |  Sex: "), s$SEX,
      tags$strong("  |  Site: "), s$SITEID
    )
  })
  
  output$plot_subj_timeline <- renderPlotly({
    df <- subj_ae() %>% filter(!is.na(ASTDY))
    validate(need(nrow(df) > 0, "No adverse events recorded for this subject."))
    
    # open-ended / ongoing events: draw a minimal segment at the start day
    df$AENDY[is.na(df$AENDY)] <- df$ASTDY[is.na(df$AENDY)]
    
    p <- plot_ly()
    for (i in seq_len(nrow(df))) {
      col <- unname(sev_cols[df$AESEV[i]])
      if (is.na(col)) col <- "#777777"
      p <- add_segments(
        p,
        x = df$ASTDY[i], xend = df$AENDY[i],
        y = df$AEDECOD[i], yend = df$AEDECOD[i],
        line = list(color = col, width = 8),
        showlegend = FALSE,
        hoverinfo = "text",
        text = paste0(df$AEDECOD[i],
                      "<br>Day ", df$ASTDY[i], " to ", df$AENDY[i],
                      "<br>Severity: ", df$AESEV[i],
                      "<br>Serious: ", df$AESER[i])
      )
    }
    p %>% layout(xaxis = list(title = "Study Day"),
                 yaxis = list(title = ""),
                 margin = list(l = 10))
  })
  
  output$subj_ae_table <- renderDT({
    subj_ae() %>%
      select(AESOC, AEDECOD, AESEV, AEREL, AESER, TRTEMFL, ASTDY, AENDY)
  }, options = list(pageLength = 5, dom = "tp"), rownames = FALSE)
}

shinyApp(ui, server)

