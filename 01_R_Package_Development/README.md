## 01. R Package Development

Two R packages built from scratch as part of my clinical programming
portfolio: package structure, `roxygen2` documentation, `testthat` unit
tests, and `devtools::check()` passing with 0 errors / 0 warnings.

|Package|What it does|Folder|
|-|-|-|
|[`descriptiveStats`](./descriptive_stats)|Fundamental descriptive statistics — mean, median, mode, quartiles (Q1, Q3) and IQR — with NA-aware handling and informative errors on edge cases (empty input, non-numeric input, all-NA vectors).|`descriptive_stats/`|
|[`classiccompare`](./classiccompare)|Compares two data frames and reports differences in variables, observations and values, in the style of SAS's `PROC COMPARE`. Supports `ID`/`BY`-style observation matching, `EXACT`/`ABSOLUTE`/`RELATIVE`/`PERCENT` comparison methods, `VAR`/`WITH` variable selection, `NOVALUES`, `LISTALL`, and a `SYSINFO`-style bitmask return code for automated QC checks.|`classiccompare/`|

## Setup instructions

Each package has its own instructions file with install, usage, test and
CRAN-check commands:

* [`instructions_descriptiveStats.txt`](./instructions_descriptiveStats.txt)
* [`instructions_classiccompare.txt`](./instructions_classiccompare.txt)

Both are self-contained: install directly from the built tarball, or from
the source folder with `devtools::install()`.

## Quick install

```r
if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")

# descriptiveStats
devtools::install_local(
  here::here("01_R_Package_Development", "descriptiveStats_0.1.0.tar.gz")
)

# classiccompare
devtools::install_local(
  here::here("01_R_Package_Development", "classiccompare_0.0.0.9000.tar.gz")
)
```

## Why SAS PROC COMPARE in R

`classiccompare` was built to replicate a tool used daily in clinical
programming QC — comparing production and validation datasets (e.g. two
versions of `ADSL`) — for teams working in R (`pharmaverse`) rather than
SAS, while keeping the return-code-driven, automatable workflow that
`PROC COMPARE` and `SYSINFO` provide in a SAS environment.

=======
# 01\. R Package Development

Two R packages built from scratch as part of my clinical programming
portfolio: package structure, `roxygen2` documentation, `testthat` unit
tests, and `devtools::check()` passing with 0 errors / 0 warnings.

|Package|What it does|Folder|
|-|-|-|
|[`descriptiveStats`](./descriptive_stats)|Fundamental descriptive statistics — mean, median, mode, quartiles (Q1, Q3) and IQR — with NA-aware handling and informative errors on edge cases (empty input, non-numeric input, all-NA vectors).|`descriptive_stats/`|
|[`classiccompare`](./classiccompare)|Compares two data frames and reports differences in variables, observations and values, in the style of SAS's `PROC COMPARE`. Supports `ID`/`BY`-style observation matching, `EXACT`/`ABSOLUTE`/`RELATIVE`/`PERCENT` comparison methods, `VAR`/`WITH` variable selection, `NOVALUES`, `LISTALL`, and a `SYSINFO`-style bitmask return code for automated QC checks.|`classiccompare/`|

## Setup instructions

Each package has its own instructions file with install, usage, test and
CRAN-check commands:

* [`instructions_descriptiveStats.txt`](./instructions_descriptiveStats.txt)
* [`instructions_classiccompare.txt`](./instructions_classiccompare.txt)

Both are self-contained: install directly from the built tarball, or from
the source folder with `devtools::install()`.

## Quick install

```r
if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")

# descriptiveStats
devtools::install_local(
  here::here("01_R_Package_Development", "descriptiveStats_0.1.0.tar.gz")
)

# classiccompare
devtools::install_local(
  here::here("01_R_Package_Development", "classiccompare_0.0.0.9000.tar.gz")
)
```

## Why SAS PROC COMPARE in R

`classiccompare` was built to replicate a tool used daily in clinical
programming QC — comparing production and validation datasets (e.g. two
versions of `ADSL`) — for teams working in R (`pharmaverse`) rather than
SAS, while keeping the return-code-driven, automatable workflow that
`PROC COMPARE` and `SYSINFO` provide in a SAS environment.