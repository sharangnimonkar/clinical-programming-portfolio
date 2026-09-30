# classiccompare

Compare two data frames and get a structured report of the differences in
variables, observations and values, plus a return code for automated QC.

## Installation

```r
# from a local clone
devtools::install("path/to/classiccompare")
```

## Example

```r
library(classiccompare)

base <- data.frame(id = c("A", "B", "C"), x = c(1, 2, 3), y = c("a", "b", "c"))
comp <- data.frame(id = c("C", "A", "D"), x = c(3, 1.5, 9), y = c("c", "a", "d"))

res <- classic_compare(base, comp, id = "id", listall = TRUE)
res

sysinfo(res)                 # 4288
sysinfo_decode(sysinfo(res)) # "BASEOBS" "COMPOBS" "VALUE"
```

## Matching

- No `id` or `by`: observations are paired by position.
- `id`: observations are paired on the ID values.
- `by`: observations are paired by position within each BY group.

## Tolerances

`method` is `"exact"`, `"absolute"`, `"relative"` or `"percent"`, with
`criterion` as the threshold. Supplying only `criterion` switches to
`"absolute"`.

## Use in QC scripts

```r
res <- classic_compare(prod_adsl, qc_adsl, id = "USUBJID")
stopifnot(sysinfo(res) == 0L)
```

## Not implemented

Variable lengths, informats, dataset types and special missing values are
not compared, because R data frames do not carry them.
