# Character values ignore trailing blanks (as in SAS); NA gets a sentinel
# so a missing value never collides with the text "NA"
build_key <- function(df, cols) {
  if (length(cols) == 0L) return(rep("", nrow(df)))
  parts <- lapply(df[cols], function(x) {
    s <- as.character(x)
    if (is.character(x) || is.factor(x)) s <- sub(" +$", "", s)
    s[is.na(s)] <- "\x1eNA"
    s
  })
  do.call(paste, c(unname(parts), sep = "\x1f"))
}

# 1, 2, 3... within each distinct key, in original row order
occurrence <- function(key) {
  occ <- integer(length(key))
  if (length(key) == 0L) return(occ)
  o <- order(key, method = "radix")   # radix = byte-exact, stable ordering
  occ[o] <- sequence(rle(key[o])$lengths)
  occ
}

match_observations <- function(base, compare, id = NULL, by = NULL) {
  stopifnot(is.data.frame(base), is.data.frame(compare))

  keys <- c(by, id)
  cols_base <- cols_compare <- character(0)

  if (length(keys) > 0L) {
    a <- var_attrs(base)
    b <- var_attrs(compare)
    ku <- toupper(keys)

    miss_a <- keys[!ku %in% a$key]
    miss_b <- keys[!ku %in% b$key]
    if (length(miss_a)) stop("BY/ID variable(s) not in base: ",
                             paste(miss_a, collapse = ", "), call. = FALSE)
    if (length(miss_b)) stop("BY/ID variable(s) not in compare: ",
                             paste(miss_b, collapse = ", "), call. = FALSE)

    ia <- match(ku, a$key)
    ib <- match(ku, b$key)
    bad <- a$type[ia] != b$type[ib]
    if (any(bad)) stop("BY/ID variable(s) differ in type: ",
                       paste(keys[bad], collapse = ", "), call. = FALSE)

    cols_base    <- a$name[ia]
    cols_compare <- b$name[ib]
  }

  key_base    <- build_key(base, cols_base)
  key_compare <- build_key(compare, cols_compare)

  full_base    <- paste(key_base,    occurrence(key_base),    sep = "\x1f")
  full_compare <- paste(key_compare, occurrence(key_compare), sep = "\x1f")

  m <- match(full_base, full_compare)   # compare row for each base row, or NA
  hit <- which(!is.na(m))

  matched <- data.frame(base_row = hit, compare_row = m[hit])

  structure(
    list(
      matched      = matched,
      only_base    = which(is.na(m)),
      only_compare = setdiff(seq_len(nrow(compare)), m[hit]),
      n_base       = nrow(base),
      n_compare    = nrow(compare),
      n_common     = nrow(matched),
      id           = id,
      by           = by
    ),
    class = "classic_compare_obs"
  )
}
