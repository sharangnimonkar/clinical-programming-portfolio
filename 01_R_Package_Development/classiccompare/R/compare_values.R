fmt_num <- function(v) {
  s <- sprintf("%.15g", v)
  s[is.na(v)] <- NA_character_
  s
}

# TRUE where a pair of numeric values compares unequal
num_unequal <- function(x, y, method, criterion, fuzz = 0) {
  na_x <- is.na(x)
  na_y <- is.na(y)
  out  <- na_x != na_y                   # one missing, the other not
  ok   <- !na_x & !na_y & x != y         # identical values are never flagged
  if (any(ok)) {
    d <- abs(y[ok] - x[ok])
    m <- switch(method,
                exact    = ,
                absolute = d,
                relative = d / abs(x[ok]),
                percent  = 100 * d / abs(x[ok])
    )
    out[ok] <- m > criterion & d > fuzz
  }
  out
}

# Character: trailing blanks ignored, NA treated as blank, case-sensitive
chr_unequal <- function(x, y) {
  x[is.na(x)] <- ""
  y[is.na(y)] <- ""
  sub(" +$", "", x) != sub(" +$", "", y)
}

compare_values <- function(base, compare, vars, obs,
                           criterion = NULL, method = NULL, fuzz = 0) {
  stopifnot(inherits(vars, "classic_compare_vars"),
            inherits(obs,  "classic_compare_obs"))

  if (is.null(method)) {
    method <- if (is.null(criterion)) "exact" else "absolute"
  } else {
    method <- match.arg(method, c("exact", "absolute", "relative", "percent"))
  }
  if (method == "exact") {
    if (!is.null(criterion)) {
      warning("CRITERION is ignored when METHOD is exact", call. = FALSE)
    }
    criterion <- 0
  } else if (is.null(criterion)) {
    criterion <- 1e-5
  }

  common <- vars$common
  skip   <- toupper(c(obs$by, obs$id))
  cv <- common[!common$type_diff & !toupper(common$variable) %in% skip, ,
               drop = FALSE]

  rows_b <- obs$matched$base_row
  rows_c <- obs$matched$compare_row

  empty_summary <- data.frame(
    variable = character(), type = character(), n_compared = integer(),
    n_diff = integer(), max_abs_diff = numeric(), stringsAsFactors = FALSE
  )
  empty_details <- data.frame(
    variable = character(), base_row = integer(), compare_row = integer(),
    base_value = character(), compare_value = character(),
    diff = numeric(), pct_diff = numeric(), stringsAsFactors = FALSE
  )

  summ <- vector("list", nrow(cv))
  det  <- vector("list", nrow(cv))

  for (i in seq_len(nrow(cv))) {
    nm   <- cv$variable[i]
    nm_c <- names(compare)[match(toupper(nm), toupper(names(compare)))]

    if (cv$type_base[i] == "Num") {
      x   <- as.numeric(base[[nm]][rows_b])
      y   <- as.numeric(compare[[nm_c]][rows_c])
      ne  <- num_unequal(x, y, method, criterion, fuzz)
      d   <- y - x
      pct <- 100 * d / x
      xs  <- fmt_num(x)
      ys  <- fmt_num(y)
    } else {
      xs  <- as.character(base[[nm]][rows_b])
      ys  <- as.character(compare[[nm_c]][rows_c])
      ne  <- chr_unequal(xs, ys)
      d   <- pct <- rep(NA_real_, length(xs))
    }

    hit <- which(ne)
    summ[[i]] <- data.frame(
      variable   = nm,
      type       = cv$type_base[i],
      n_compared = length(ne),
      n_diff     = length(hit),
      max_abs_diff = if (length(hit) && any(!is.na(d[hit]))) {
        max(abs(d[hit]), na.rm = TRUE)
      } else NA_real_,
      stringsAsFactors = FALSE
    )
    det[[i]] <- data.frame(
      variable      = rep(nm, length(hit)),
      base_row      = rows_b[hit],
      compare_row   = rows_c[hit],
      base_value    = xs[hit],
      compare_value = ys[hit],
      diff          = d[hit],
      pct_diff      = pct[hit],
      stringsAsFactors = FALSE
    )
  }

  structure(
    list(
      summary      = do.call(rbind, c(list(empty_summary), summ)),
      details      = do.call(rbind, c(list(empty_details), det)),
      not_compared = common$variable[common$type_diff],
      method       = method,
      criterion    = criterion,
      fuzz         = fuzz,
      n_obs        = length(rows_b)
    ),
    class = "classic_compare_values"
  )
}
