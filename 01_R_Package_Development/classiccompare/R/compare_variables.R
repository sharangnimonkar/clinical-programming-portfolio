`%||%` <- function(x, y) if (is.null(x)) y else x

# One row per variable, with the attributes the report covers
var_attrs <- function(df) {
  data.frame(
    name   = names(df),
    key    = toupper(names(df)),   # SAS variable names are case-insensitive
    type   = vapply(df, function(x) {
      if (is.character(x) || is.factor(x)) "Char" else "Num"
    }, character(1)),
    label  = vapply(df, function(x) attr(x, "label", exact = TRUE) %||% "", character(1)),
    format = vapply(df, function(x) attr(x, "format.sas", exact = TRUE) %||% "", character(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

compare_variables <- function(base, compare) {
  stopifnot(is.data.frame(base), is.data.frame(compare))

  a <- var_attrs(base)
  b <- var_attrs(compare)

  common_keys <- a$key[a$key %in% b$key]
  ia <- match(common_keys, a$key)
  ib <- match(common_keys, b$key)

  common <- data.frame(
    variable       = a$name[ia],
    type_base      = a$type[ia],    type_compare   = b$type[ib],
    label_base     = a$label[ia],   label_compare  = b$label[ib],
    format_base    = a$format[ia],  format_compare = b$format[ib],
    stringsAsFactors = FALSE
  )
  common$type_diff   <- common$type_base   != common$type_compare
  common$label_diff  <- common$label_base  != common$label_compare
  common$format_diff <- common$format_base != common$format_compare

  structure(
    list(
      common       = common,
      only_base    = a$name[!a$key %in% b$key],
      only_compare = b$name[!b$key %in% a$key]
    ),
    class = "classic_compare_vars"
  )
}
