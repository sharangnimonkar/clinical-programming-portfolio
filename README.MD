# Clinical Programming Portfolio

![R Workflow](https://github.com/sharangnimonkar/clinical-programming-portfolio/actions/workflows/r-workflow.yml/badge.svg)

This repository showcases my technical portfolio in clinical programming using **R**, **Python**, and **CDISC standards**. It demonstrates modern programming workflows for clinical trial data processing, analysis dataset creation, reporting, and automation.

## Repository Structure

```
clinical-programming-portfolio/
│
├── README.md
├── Clinical_Programming_Portfolio.Rproj
├── .github/workflows/                    # CI: R CMD check on every push
│
├── 01_R_Package_Development/
├── 02_SDTM_Programming/
├── 03_ADaM_Programming/
├── 04_TLG_Generation/
├── 05_Python_Data_Processing/
├── 06_AI_Clinical_Data_Agent/
└── 07_RShiny_Safety_Monitoring_Dashboard/
```

## Project Modules

### 01. R Package Development
Two R packages built from scratch, with `roxygen2` documentation, `testthat` unit tests, vignettes, and `R CMD check` passing with 0 errors and 0 warnings. Both are checked automatically with GitHub Actions on every push.

| Package | What it does |
|---|---|
| [`descriptiveStats`](./01_R_Package_Development/descriptive_stats) | Descriptive statistics (mean, median, mode, quartiles, IQR) with NA-aware handling and informative errors for edge cases such as empty, non-numeric, or all-NA input. |
| [`classiccompare`](./01_R_Package_Development/classiccompare) | Compares two datasets and reports differences in variables, observations, and values, in the style of SAS `PROC COMPARE`. Supports `ID`/`BY` matching, `EXACT`/`ABSOLUTE`/`RELATIVE`/`PERCENT` methods, `VAR`/`WITH` selection, and a `SYSINFO`-style return code for automated QC. |

`classiccompare` was built for production-versus-validation dataset comparison (for example, two versions of `ADSL`) in R/pharmaverse teams, keeping the return-code-driven workflow that `PROC COMPARE` provides in SAS.

### 02. SDTM Programming
- Creation of SDTM domains
- Controlled terminology implementation
- Data validation and quality checks

### 03. ADaM Programming
- Development of ADaM datasets
- Subject-level analysis dataset creation
- Traceability from SDTM to ADaM

### 04. TLG Generation
- Adverse Event summary tables
- Patient listings
- Safety visualizations
- HTML and PDF report generation

### 05. Python Data Processing
- Clinical dataset manipulation
- Automated data processing workflows

### 06. AI Clinical Data Agent
- AI-assisted clinical data processing
- Automated query handling
- Python-based workflow implementation

### 07. R Shiny Safety Monitoring Dashboard(https://sharangnimonkar-clinical-safety-monitoring-dashboard.share.connect.posit.cloud)
- Interactive AE safety review dashboard built on pharmaverseadam ADaM datasets
- Subject-level incidence summaries by SOC and preferred term
- AE listings and per-subject adverse event timelines
- Reactive filtering by treatment arm, severity, and treatment-emergent status

## Technologies

- R Programming
- Pharmaverse
- Python
- CDISC SDTM
- CDISC ADaM
- Tables, Listings & Graphs (TLGs)
- HTML/PDF Reporting
- R package development (`devtools`, `roxygen2`, `testthat`)
- R Shiny Dashboard
- GitHub Actions (CI)
- Git & GitHub

## Skills Demonstrated

- Clinical data programming
- Dataset QC and validation (double-programming comparison)
- Reproducible workflows
- Data transformation and validation
- Report automation
- Interactive clinical safety monitoring and visualization using R Shiny
- R package development with automated testing and continuous integration
- Software development best practices
- Cross-language programming (R & Python)