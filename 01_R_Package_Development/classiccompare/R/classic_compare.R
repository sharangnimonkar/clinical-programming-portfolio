#' Compare two datasets
#'
#' Compares a `base` data frame against a `compare` data frame and reports
#' differences in variables, observations and values.
#'
#' Observations are matched on the `id` and `by` values plus an occurrence
#' counter, so duplicate keys are paired in order of appearance and the data
#' do not need to be sorted. With neither `id` nor `by`, observations are
#' paired by position.
#'
#' Only variables present in both data frames with the same type are
#' compared, and `id` and `by` variables are excluded from the value
#' comparison. Variable names are matched case-insensitively. Character
#' values ignore trailing blanks, are case-sensitive, and treat missing as
#' blank. For numeric values, two missing values are equal and one missing
#' value against a non-missing one is a difference.
#'
#' The difference is `compare - base`. With `method = "relative"` or
#' `"percent"` it is scaled by the base value.
#'
#' @param base,compare Data frames to compare.
#' @param id Character vector of variables that identify observations.
#'   Observations are paired on these values.
#' @param by Character vector of BY variables. Observations are paired by
#'   position within each BY group. Can be combined with `id`.
#' @param var,with Character vectors of variables to compare. Use `with` to
#'   compare differently named variables: `var[i]` in `base` against
#'   `with[i]` in `compare`. `with` requires `var`.
#' @param criterion Numeric tolerance. Supplying it alone switches `method`
#'   to `"absolute"`. Defaults to `1e-5` for the non-exact methods.
#' @param method One of `"exact"` (the default), `"absolute"`, `"relative"`
#'   or `"percent"`.
#' @param fuzz Numeric. Pairs whose absolute difference is within `fuzz` are
#'   treated as equal.
#' @param maxprint Maximum number of differences printed per variable and in
#'   total, as `c(per_variable, total)`. Affects printing only; all
#'   differences are stored in the result.
#' @param listall Logical. If `TRUE`, the printed report also lists
#'   unmatched observations and variables with all values equal.
#' @param novalues Logical. If `TRUE`, values are not compared: the
#'   Values Comparison Summary and Value Comparison Results sections are
#'   omitted, and the `VALUE` bit of [sysinfo()] is never set. Equivalent to
#'   the `NOVALUES` option in SAS's dataset comparison utility.
#'
#' @return An object of class `classic_compare`: a list with the summary
#'   counts (`counts`), variable comparison (`vars`), observation matching
#'   (`obs`), value comparison (`values`, including a `details` data frame
#'   with one row per unequal value), the return code (`sysinfo`) and the
#'   conditions behind it (`sysinfo_flags`).
#' @seealso [sysinfo()], [sysinfo_decode()]
#' @examples
#' base <- data.frame(id = c("A", "B", "C"), x = c(1, 2, 3), y = c("a", "b", "c"))
#' comp <- data.frame(id = c("C", "A", "D"), x = c(3, 1.5, 9), y = c("c", "a", "d"))
#'
#' res <- classic_compare(base, comp, id = "id", listall = TRUE)
#' res
#' sysinfo(res)
#' sysinfo_decode(sysinfo(res))
#'
#' # Tolerance-based comparison: a 0.4% difference passes a 0.5% criterion
#' classic_compare(data.frame(x = 100), data.frame(x = 100.4),
#'                 method = "percent", criterion = 0.5)
#'
#' # Structure-only comparison: no value comparison at all
#' classic_compare(base, comp, id = "id", novalues = TRUE, listall = TRUE)
#' @export
classic_compare <- function(base, compare, id = NULL, by = NULL,
                            var = NULL, with = NULL,
                            criterion = NULL, method = NULL, fuzz = 0,
                            maxprint = c(50, 500), listall = FALSE,
                            novalues = FALSE) {
  base_name    <- deparse(substitute(base))[1]
  compare_name <- deparse(substitute(compare))[1]
  stopifnot(is.data.frame(base), is.data.frame(compare))
  if (!is.null(with) && is.null(var)) {
    stop("WITH requires VAR", call. = FALSE)
  }
  if (length(maxprint) == 1L) maxprint <- c(maxprint, 500)

  vars <- compare_variables(base, compare)
  obs  <- match_observations(base, compare, id = id, by = by)

  if (is.null(var)) {
    val <- compare_values(base, compare, vars, obs,
                          criterion = criterion, method = method, fuzz = fuzz)
  } else {
    with <- with %||% var
    if (length(with) != length(var)) {
      stop("VAR and WITH must have the same number of variables", call. = FALSE)
    }
    ib <- match(toupper(var),  toupper(names(base)))
    ic <- match(toupper(with), toupper(names(compare)))
    if (anyNA(ib)) stop("VAR variable(s) not in base: ",
                        paste(var[is.na(ib)], collapse = ", "), call. = FALSE)
    if (anyNA(ic)) stop("WITH variable(s) not in compare: ",
                        paste(with[is.na(ic)], collapse = ", "), call. = FALSE)
    if (anyDuplicated(ib)) stop("VAR contains duplicate variables", call. = FALSE)

    # Pair base[var[i]] with compare[with[i]] by giving them the same name
    b_sub <- base[ib]
    c_sub <- compare[ic]
    names(c_sub) <- names(b_sub)
    val <- compare_values(b_sub, c_sub, compare_variables(b_sub, c_sub), obs,
                          criterion = criterion, method = method, fuzz = fuzz)
  }

  if (novalues) {
    # Compute as usual, then discard the results, so sysinfo's VALUE bit
    # and every downstream count reflect "not compared" rather than "equal".
    val$summary <- val$summary[0, , drop = FALSE]
    val$details <- val$details[0, , drop = FALSE]
  }

  sys <- compute_sysinfo(base, compare, vars, obs, val)

  keys <- c(by, id)
  key_rows <- function(df, rows) {
    out <- data.frame(row = rows)
    if (length(keys)) {
      cols <- names(df)[match(toupper(keys), toupper(names(df)))]
      out  <- cbind(out, df[rows, cols, drop = FALSE])
    }
    rownames(out) <- NULL
    out
  }

  s <- val$summary
  counts <- list(
    datasets = data.frame(
      dataset = c(base_name, compare_name),
      n_vars  = c(ncol(base), ncol(compare)),
      n_obs   = c(nrow(base), nrow(compare))
    ),
    variables = c(
      common       = nrow(vars$common),
      only_base    = length(vars$only_base),
      only_compare = length(vars$only_compare),
      type_diff    = sum(vars$common$type_diff),
      label_diff   = sum(vars$common$label_diff),
      format_diff  = sum(vars$common$format_diff)
    ),
    observations = c(
      base         = obs$n_base,
      compare      = obs$n_compare,
      common       = obs$n_common,
      only_base    = length(obs$only_base),
      only_compare = length(obs$only_compare),
      unequal      = length(unique(val$details$base_row))
    ),
    values = c(
      vars_compared   = nrow(s),
      vars_equal      = sum(s$n_diff == 0),
      vars_unequal    = sum(s$n_diff > 0),
      values_compared = sum(s$n_compared),
      values_unequal  = sum(s$n_diff)
    )
  )

  structure(
    list(
      counts           = counts,
      vars             = vars,
      obs              = obs,
      values           = val,
      only_base_obs    = key_rows(base, obs$only_base),
      only_compare_obs = key_rows(compare, obs$only_compare),
      detail_keys      = key_rows(base, val$details$base_row),
      var_info         = list(base = var_attrs(base), compare = var_attrs(compare)),
      maxprint         = maxprint,
      listall          = listall,
      novalues         = novalues,
      sysinfo          = sys$code,
      sysinfo_flags    = sys$flags
    ),
    class = "classic_compare"
  )
}


#' @export
print.classic_compare <- function(x, width = min(getOption("width", 80L), 100L), ...) {
  cn  <- x$counts
  bn  <- cn$datasets$dataset[1]
  cpn <- cn$datasets$dataset[2]
  val <- x$values
  s   <- val$summary
  d   <- val$details
  cm  <- x$vars$common

  # ---- layout helpers -------------------------------------------------------
  gap     <- function(n = 1L) writeLines(rep("", n))
  ctr     <- function(text) paste0(strrep(" ", max(0L, (width - nchar(text)) %/% 2L)), text)
  put     <- function(text) writeLines(ctr(text))
  heading <- function(text) { gap(2L); put(text); gap() }
  block   <- function(lines) {
    if (!length(lines)) return(invisible())
    pad <- max(0L, (width - max(nchar(lines))) %/% 2L)
    writeLines(sub(" +$", "", paste0(strrep(" ", pad), lines)))
  }
  cnt  <- function(label, n) sprintf("%s: %d.", label, as.integer(n))
  lj   <- function(v, w) formatC(v, width = w, flag = "-")
  rj   <- function(v, w) formatC(v, width = w)
  clean <- function(v) { v <- as.character(v); v[is.na(v)] <- ""; v }
  fmt_val <- function(v) {
    out <- sprintf("%.7g", v)
    out[!is.finite(v)] <- "."
    out
  }
  type_lbl <- function(t) ifelse(t == "Char", "CHAR", "NUM")

  # Simple text table: columns in `left` are left-aligned, the rest right-aligned
  tbl <- function(df, left = 1L) {
    df[] <- lapply(df, clean)
    w <- vapply(seq_along(df),
                function(i) max(nchar(c(names(df)[i], df[[i]]))), integer(1))
    cell <- function(v, i) if (i %in% left) lj(v, w[i]) else rj(v, w[i])
    hdr  <- paste(vapply(seq_along(df), function(i) cell(names(df)[i], i), ""),
                  collapse = "  ")
    rows <- if (nrow(df)) {
      do.call(paste, c(lapply(seq_along(df), function(i) cell(df[[i]], i)), sep = "  "))
    } else character(0)
    c(hdr, "", rows)
  }

  # Value listing for one variable, laid out as base | compare | diff | % diff
  grid <- function(keydf, vn, bv, cv, dv = NULL, pv = NULL) {
    kc <- lapply(keydf, clean)
    kw <- vapply(seq_along(kc), function(j) max(nchar(c(names(kc)[j], kc[[j]]))), integer(1))
    vc <- list(list(h1 = "Base Value",    h2 = vn, v = bv),
               list(h1 = "Compare Value", h2 = vn, v = cv))
    if (!is.null(dv)) {
      vc <- c(vc, list(list(h1 = "", h2 = "Diff.",  v = dv),
                       list(h1 = "", h2 = "% Diff", v = pv)))
    }
    vw <- vapply(vc, function(cc) max(nchar(c(cc$h1, cc$h2, cc$v))), integer(1))
    sep <- "  ||  "
    kpart <- function(f) paste(vapply(seq_along(kc), function(j) f(j), ""), collapse = "  ")
    vpart <- function(f) paste(vapply(seq_along(vc), function(j) f(j), ""), collapse = "  ")

    hdr1 <- paste0(strrep(" ", sum(kw) + 2L * (length(kw) - 1L)), sep,
                   vpart(function(j) rj(vc[[j]]$h1, vw[j])))
    hdr2 <- paste0(kpart(function(j) lj(names(kc)[j], kw[j])), sep,
                   vpart(function(j) rj(vc[[j]]$h2, vw[j])))
    rule <- paste0(kpart(function(j) strrep("_", kw[j])), sep,
                   vpart(function(j) strrep("_", vw[j])))
    body <- vapply(seq_along(kc[[1]]), function(r) {
      paste0(kpart(function(j) lj(kc[[j]][r], kw[j])), sep,
             vpart(function(j) rj(vc[[j]]$v[r], vw[j])))
    }, "")
    edge <- strrep("_", nchar(hdr2))
    c(edge, hdr1, hdr2, rule, body, edge)
  }

  # ---- title ----------------------------------------------------------------
  gap()
  put("The Classic Compare Report")
  put(sprintf("Comparison of %s with %s", bn, cpn))
  meth <- if (x$novalues) "Values Not Compared (NOVALUES)" else if (val$method == "exact") "Method=EXACT" else
    sprintf("Method=%s, Criterion=%s", toupper(val$method), format(val$criterion))
  if (!x$novalues && val$fuzz > 0) meth <- paste0(meth, ", Fuzz=", format(val$fuzz))
  put(paste0("(", meth, ")"))

  # ---- data set summary -----------------------------------------------------
  heading("Data Set Summary")
  block(tbl(data.frame(Dataset = cn$datasets$dataset,
                       NVar    = cn$datasets$n_vars,
                       NObs    = cn$datasets$n_obs,
                       stringsAsFactors = FALSE)))

  # ---- variables summary ----------------------------------------------------
  heading("Variables Summary")
  v <- cn$variables
  n_attr <- sum(cm$label_diff | cm$format_diff)
  block(c(
    cnt("Number of Variables in Common", v[["common"]]),
    if (v[["only_base"]] > 0)
      cnt(sprintf("Number of Variables in %s but not in %s", bn, cpn), v[["only_base"]]),
    if (v[["only_compare"]] > 0)
      cnt(sprintf("Number of Variables in %s but not in %s", cpn, bn), v[["only_compare"]]),
    if (v[["type_diff"]] > 0)
      cnt("Number of Variables with Conflicting Types", v[["type_diff"]]),
    if (n_attr > 0)
      cnt("Number of Variables with Differing Attributes", n_attr),
    if (length(x$obs$id) > 0) cnt("Number of ID Variables", length(x$obs$id)),
    if (length(x$obs$by) > 0) cnt("Number of BY Variables", length(x$obs$by))
  ))

  info_tbl <- function(info, keep) {
    i  <- info[match(keep, info$name), , drop = FALSE]
    df <- data.frame(Variable = i$name, Type = type_lbl(i$type), stringsAsFactors = FALSE)
    if (any(nzchar(i$label))) df$Label <- i$label
    df
  }
  if (length(x$vars$only_base)) {
    heading(sprintf("Listing of Variables in %s but not in %s", bn, cpn))
    block(tbl(info_tbl(x$var_info$base, x$vars$only_base), left = 1:3))
  }
  if (length(x$vars$only_compare)) {
    heading(sprintf("Listing of Variables in %s but not in %s", cpn, bn))
    block(tbl(info_tbl(x$var_info$compare, x$vars$only_compare), left = 1:3))
  }

  differ <- cm[cm$type_diff | cm$label_diff | cm$format_diff, , drop = FALSE]
  if (nrow(differ)) {
    heading("Listing of Common Variables with Differing Attributes")
    rows <- do.call(rbind, lapply(seq_len(nrow(differ)), function(i) {
      data.frame(Variable = c(differ$variable[i], ""),
                 Dataset  = c(bn, cpn),
                 Type     = toupper(c(differ$type_base[i], differ$type_compare[i])),
                 Format   = c(differ$format_base[i], differ$format_compare[i]),
                 Label    = c(differ$label_base[i], differ$label_compare[i]),
                 stringsAsFactors = FALSE)
    }))
    if (!any(nzchar(rows$Format))) rows$Format <- NULL
    if (!any(nzchar(rows$Label)))  rows$Label  <- NULL
    block(tbl(rows, left = seq_len(ncol(rows))))
  }

  # ---- observation summary --------------------------------------------------
  heading("Observation Summary")
  m   <- x$obs$matched
  na2 <- c(NA_integer_, NA_integer_)
  rng <- function(a, b, f) if (length(a)) c(f(a), f(b)) else na2
  pos <- list("First Obs" = rng(m$base_row, m$compare_row, min))
  if (nrow(d)) {
    pos[["First Unequal"]] <- rng(d$base_row, d$compare_row, min)
    pos[["Last  Unequal"]] <- rng(d$base_row, d$compare_row, max)
  }
  pos[["Last  Obs"]] <- rng(m$base_row, m$compare_row, max)
  block(tbl(data.frame(Observation = names(pos),
                       Base    = vapply(pos, function(p) as.integer(p[1]), 1L),
                       Compare = vapply(pos, function(p) as.integer(p[2]), 1L),
                       stringsAsFactors = FALSE, row.names = NULL)))
  gap()
  o <- cn$observations
  block(c(
    cnt("Number of Observations in Common", o[["common"]]),
    if (o[["only_base"]] > 0)
      cnt(sprintf("Number of Observations in %s but not in %s", bn, cpn), o[["only_base"]]),
    if (o[["only_compare"]] > 0)
      cnt(sprintf("Number of Observations in %s but not in %s", cpn, bn), o[["only_compare"]]),
    cnt(sprintf("Total Number of Observations Read from %s", bn),  o[["base"]]),
    cnt(sprintf("Total Number of Observations Read from %s", cpn), o[["compare"]]),
    if (!x$novalues) cnt("Number of Observations with Some Compared Variables Unequal", o[["unequal"]]),
    if (!x$novalues) cnt("Number of Observations with All Compared Variables Equal",
                         o[["common"]] - o[["unequal"]])
  ))

  key_tbl <- function(k) {
    names(k)[names(k) == "row"] <- "Obs"
    tbl(k, left = setdiff(seq_len(ncol(k)), 1L))
  }
  if (x$listall) {
    if (o[["only_base"]] > 0) {
      heading(sprintf("Listing of Observations in %s but not in %s", bn, cpn))
      block(key_tbl(x$only_base_obs))
    }
    if (o[["only_compare"]] > 0) {
      heading(sprintf("Listing of Observations in %s but not in %s", cpn, bn))
      block(key_tbl(x$only_compare_obs))
    }
  }

  if (!x$novalues) {
    # ---- values comparison summary --------------------------------------------
    heading("Values Comparison Summary")
    vl <- cn$values
    mx <- if (any(!is.na(s$max_abs_diff))) max(s$max_abs_diff, na.rm = TRUE) else NA_real_
    block(c(
      cnt("Number of Variables Compared with All Observations Equal", vl[["vars_equal"]]),
      cnt("Number of Variables Compared with Some Observations Unequal", vl[["vars_unequal"]]),
      cnt("Total Number of Values which Compare Unequal", vl[["values_unequal"]]),
      if (!is.na(mx)) sprintf("Maximum Difference: %s.", fmt_val(mx))
    ))
    if (length(val$not_compared)) {
      gap()
      block(sprintf("NOTE: Not compared (conflicting types): %s",
                    paste(val$not_compared, collapse = ", ")))
    }

    unequal_vars <- s[s$n_diff > 0, , drop = FALSE]
    if (nrow(unequal_vars)) {
      heading("Variables with Unequal Values")
      block(tbl(data.frame(
        Variable = unequal_vars$variable,
        Type     = type_lbl(unequal_vars$type),
        Ndif     = unequal_vars$n_diff,
        MaxDif   = ifelse(unequal_vars$type == "Char", "", fmt_val(unequal_vars$max_abs_diff)),
        stringsAsFactors = FALSE), left = 1:2))
    }
    if (x$listall) {
      equal_vars <- s[s$n_diff == 0, , drop = FALSE]
      if (nrow(equal_vars)) {
        heading("Variables with All Values Equal")
        block(tbl(data.frame(Variable = equal_vars$variable,
                             Type = type_lbl(equal_vars$type),
                             stringsAsFactors = FALSE), left = 1:2))
      }
    }

    # ---- value comparison results ---------------------------------------------
    if (nrow(d) == 0L) {
      gap()
      block("NOTE: No unequal values were found. All values compared are exactly equal.")
    } else {
      heading("Value Comparison Results for Variables")
      kcols <- setdiff(names(x$detail_keys), "row")
      shown <- 0L
      for (vn in unique(d$variable)) {
        idx  <- which(d$variable == vn)
        room <- min(x$maxprint[1], x$maxprint[2] - shown)
        if (room <= 0L) {
          block("NOTE: MAXPRINT total limit reached; remaining variables not printed.")
          break
        }
        n_all <- length(idx)
        idx   <- idx[seq_len(min(room, n_all))]
        is_num <- s$type[match(vn, s$variable)] == "Num"
        kd <- x$detail_keys[idx, , drop = FALSE]
        keydf <- if (length(kcols)) kd[kcols] else data.frame(Obs = kd$row)
        if (is_num) {
          lines <- grid(keydf, vn,
                        fmt_val(as.numeric(d$base_value[idx])),
                        fmt_val(as.numeric(d$compare_value[idx])),
                        fmt_val(d$diff[idx]), fmt_val(d$pct_diff[idx]))
        } else {
          lines <- grid(keydf, vn, clean(d$base_value[idx]), clean(d$compare_value[idx]))
        }
        block(lines)
        if (length(idx) < n_all) {
          block(sprintf("NOTE: %d of %d differences printed for %s (MAXPRINT).",
                        length(idx), n_all, vn))
        }
        gap()
        shown <- shown + length(idx)
      }
    }
  } else {
    gap()
    block("NOTE: NOVALUES specified; values were not compared.")
  }

  # ---- return code ----------------------------------------------------------
  heading("Return Code")
  block(c(sprintf("SYSINFO: %d", x$sysinfo),
          if (length(x$sysinfo_flags))
            paste("Conditions:", paste(x$sysinfo_flags, collapse = ", "))))
  gap()
  invisible(x)
}
