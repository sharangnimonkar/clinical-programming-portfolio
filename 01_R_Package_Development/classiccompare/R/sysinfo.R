# Bit values as I recall them from the SAS SYSINFO documentation.
# Verify against the table in the SAS docs for your version.
sysinfo_bits <- c(
  DSLABEL = 1L,    DSTYPE  = 2L,    INFORMAT = 4L,   FORMAT  = 8L,
  LENGTH  = 16L,   LABEL   = 32L,   BASEOBS  = 64L,  COMPOBS = 128L,
  BASEBY  = 256L,  COMPBY  = 512L,  BASEVAR  = 1024L, COMPVAR = 2048L,
  VALUE   = 4096L, TYPE    = 8192L, BYVAR    = 16384L, ERROR  = 32768L
)

# Are there BY groups present in one dataset but not the other?
by_groups_only <- function(base, compare, by) {
  if (length(by) == 0L) return(c(base = FALSE, compare = FALSE))
  a <- names(base)[match(toupper(by), toupper(names(base)))]
  b <- names(compare)[match(toupper(by), toupper(names(compare)))]
  ka <- unique(build_key(base, a))
  kb <- unique(build_key(compare, b))
  c(base = any(!ka %in% kb), compare = any(!kb %in% ka))
}

compute_sysinfo <- function(base, compare, vars, obs, val) {
  lab <- function(df) attr(df, "label", exact = TRUE) %||% ""
  grp <- by_groups_only(base, compare, obs$by)

  flags <- c(
    DSLABEL = !identical(lab(base), lab(compare)),
    FORMAT  = any(vars$common$format_diff),
    LABEL   = any(vars$common$label_diff),
    BASEOBS = length(obs$only_base) > 0L,
    COMPOBS = length(obs$only_compare) > 0L,
    BASEBY  = grp[["base"]],
    COMPBY  = grp[["compare"]],
    BASEVAR = length(vars$only_base) > 0L,
    COMPVAR = length(vars$only_compare) > 0L,
    VALUE   = any(val$summary$n_diff > 0),
    TYPE    = any(vars$common$type_diff)
  )
  list(
    code  = as.integer(sum(sysinfo_bits[names(flags)][unname(flags)])),
    flags = names(flags)[flags]
  )
}

#' Return code of a comparison
#'
#' `sysinfo()` returns an integer bitmask summarising the differences found
#' by [classic_compare()]. A value of 0 means no differences. Each condition
#' has its own bit, so several can be set at once:
#'
#' | Condition | Value | Set when |
#' |-----------|------:|----------|
#' | DSLABEL   |     1 | dataset labels differ |
#' | FORMAT    |     8 | a common variable's format differs |
#' | LABEL     |    32 | a common variable's label differs |
#' | BASEOBS   |    64 | observations exist only in base |
#' | COMPOBS   |   128 | observations exist only in compare |
#' | BASEBY    |   256 | BY groups exist only in base |
#' | COMPBY    |   512 | BY groups exist only in compare |
#' | BASEVAR   |  1024 | variables exist only in base |
#' | COMPVAR   |  2048 | variables exist only in compare |
#' | VALUE     |  4096 | compared values differ |
#' | TYPE      |  8192 | a common variable has different types |
#'
#' @param x A `classic_compare` object.
#' @return An integer.
#' @examples
#' res <- classic_compare(data.frame(x = 1:2), data.frame(x = c(1L, 5L)))
#' sysinfo(res)
#' @export
sysinfo <- function(x) {
  stopifnot(inherits(x, "classic_compare"))
  x$sysinfo
}

#' Names of the conditions set in a return code
#'
#' @param code An integer return code from [sysinfo()].
#' @return A character vector of condition names, empty for 0.
#' @examples
#' sysinfo_decode(4096L + 64L)
#' @export
sysinfo_decode <- function(code) {
  names(sysinfo_bits)[bitwAnd(as.integer(code), sysinfo_bits) != 0L]
}
