# Safety Monitoring Dashboard (R Shiny + pharmaverseadam)

Interactive clinical safety monitoring dashboard built with R Shiny and pharmaverse ADaM datasets, providing treatment-level AE summaries, SOC/PT analysis, subject-level listings, and longitudinal AE timelines with reactive filtering.

## Features

**Overview**
- Safety population N, total AE records, serious AE count
- Top 10 preferred terms by **subject incidence (%)**, not raw event counts —
  denominator is the safety population in the selected arm
- Event severity stacked by treatment arm
- SOC-level summary table: subjects, incidence %, event count

**AE Listing**
- Full filterable/sortable AE listing (`DT` with column filters)

**Subject Profile**
- Per-subject header (arm, age, sex, site) pulled from ADSL
- AE timeline: one horizontal segment per event from `ASTDY` to `AENDY`,
  coloured by severity, with hover detail
- Per-subject AE listing

**Sidebar filters** — treatment arm, SOC, severity, treatment-emergent only
(`TRTEMFL == "Y"`, on by default), serious only (`AESER == "Y"`).

------------------------------------------------------------------------
PROJECT STRUCTURE:
------------------------------------------------------------------------
```
07_RShiny_Safety_Monitoring_Dashboard/
├── README.md                          <-- This file
├── Preview.gif                        <-- Animated walkthrough of the dashboard
└── Safety Monitoring Dashboard.R      <-- Single-file Shiny app
    │
    ├── Data load                      <-- pharmaverseadam::adsl / ::adae
    ├── pick_col()                     <-- Resolves ADaM variable names at startup
    ├── adsl_w / adae_w                <-- Standardised working frames (SAFFL == "Y")
    │
    ├── ui                             <-- dashboardPage: header, sidebar, body
    │   ├── Sidebar filters            <-- Arm, SOC, severity, TEAE, serious
    │   ├── Tab: Overview              <-- Value boxes, PT incidence, severity, SOC table
    │   ├── Tab: AE Listing            <-- Filterable DT listing
    │   └── Tab: Subject Profile       <-- ADSL header, AE timeline, per-subject listing
    │
    └── server                         <-- Reactive logic
        ├── filtered_subjects()        <-- Incidence denominator (safety population)
        ├── filtered_ae()              <-- All sidebar filters applied
        ├── plot_pt / plot_sev         <-- Overview plotly outputs
        ├── soc_table / ae_table       <-- DT outputs
        └── subj_* outputs             <-- Subject profile header, timeline, listing

```

**No `data/` directory by design.** ADSL and ADAE are loaded from the
`pharmaverseadam` package at runtime, so there is nothing to generate, stage,
or version-control — the app is reproducible from a clean checkout.

## Setup

```r
install.packages(c(
  "shiny", "shinydashboard", "DT", "plotly", "dplyr", "pharmaverseadam"
))

# The app file is not named app.R, so launch it explicitly:
shiny::runApp("Safety Monitoring Dashboard.R")
```

Alternatively, open the `.R` file in RStudio and click **Run App**.

> Note: `shiny::runApp()` with no argument only auto-detects `Safety Monitoring Dashboard.R` or an
> `ui.R`/`server.R` pair. If you'd rather use the bare call — which is also
> what `rsconnect::deployApp()` and Shiny Server expect — rename the file to
> `app.R`.

That's it — no data prep step. The datasets ship with the package.

## ADaM variables used

| Source | Variables |
|---|---|
| `adsl` | `USUBJID`, `TRT01A` (or `TRT01P`/`ACTARM`/`ARM`), `SAFFL`, `AGE`, `SEX`, `SITEID` |
| `adae` | `USUBJID`, `TRTA`, `AEBODSYS` (or `AESOC`), `AEDECOD`, `AESEV`, `AEREL`, `AESER`, `TRTEMFL`, `ASTDY`, `AENDY` |

Variable names are resolved at startup by `pick_col()`, which tries a list of
ADaM-conventional candidates and errors clearly if none are present. This
matters because pharmaverseadam's column set has shifted across versions
(`AEBODSYS` vs `AESOC`, `TRTA` vs `TRT01A`), and it means the same app runs
against a real study's ADAE/ADSL with no code change.

## Analysis conventions

- **Safety population only**: ADSL is filtered to `SAFFL == "Y"`, and ADAE is
  `semi_join`ed to that set so incidence denominators are correct.
- **Subject incidence, not event counts**, for PT and SOC summaries —
  `distinct(USUBJID, AEDECOD)` before counting, matching how AE summary
  tables are presented in a CSR.
- **Treatment-emergent filter defaults on**, as in standard safety reporting.
- Arm assignment for events comes from `TRTA` (actual treatment) rather than
  planned, consistent with safety analysis convention.

## Swapping in a real study

Replace the two lines at the top:

```r
adsl <- haven::read_sas("path/to/adsl.sas7bdat")
adae <- haven::read_sas("path/to/adae.sas7bdat")
```

Everything downstream is written against resolved variable names, so as long
as the datasets are ADaM-conformant it should run unchanged.

## Deployment

- **shinyapps.io**: `rsconnect::deployApp()` — simplest for a portfolio demo
- **Posit Connect**: internal/enterprise hosting
- **Self-hosted Shiny Server**: on-prem
