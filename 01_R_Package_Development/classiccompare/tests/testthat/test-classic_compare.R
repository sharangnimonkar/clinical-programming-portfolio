test_that("counts are assembled across the sections", {
  base <- data.frame(id = c("A", "B", "C"), x = c(1, 2, 3),
                     y = c("a", "b", "c"), only_b = 1:3)
  cmp  <- data.frame(id = c("C", "A", "D"), x = c(3, 1.5, 9),
                     y = c("c", "a", "d"), only_c = 1:3)
  res <- classic_compare(base, cmp, id = "id")

  expect_equal(res$counts$variables[["common"]], 3)
  expect_equal(res$counts$variables[["only_base"]], 1)
  expect_equal(res$counts$variables[["only_compare"]], 1)
  expect_equal(res$counts$observations[["common"]], 2)
  expect_equal(res$counts$observations[["only_base"]], 1)
  expect_equal(res$counts$observations[["only_compare"]], 1)
  expect_equal(res$counts$observations[["unequal"]], 1)
  expect_equal(res$counts$values[["values_compared"]], 4)
  expect_equal(res$counts$values[["values_unequal"]], 1)
  expect_equal(res$counts$values[["vars_equal"]], 1)
  expect_equal(res$only_base_obs$id, "B")
})

test_that("VAR/WITH compares differently named variables", {
  b <- data.frame(x = c(1, 2))
  k <- data.frame(z = c(1, 3))
  res <- classic_compare(b, k, var = "x", with = "z")
  expect_equal(res$values$summary$variable, "x")
  expect_equal(res$values$summary$n_diff, 1L)
  expect_equal(res$values$details$diff, 1)
})

test_that("VAR/WITH argument errors", {
  d <- data.frame(x = 1, y = 2)
  expect_error(classic_compare(d, d, with = "y"), "requires VAR")
  expect_error(classic_compare(d, d, var = c("x", "y"), with = "y"), "same number")
  expect_error(classic_compare(d, d, var = "nope"), "not in base")
})

test_that("MAXPRINT limits printed differences but not stored ones", {
  b <- data.frame(x = 1:10)
  k <- data.frame(x = 2:11)
  res <- classic_compare(b, k, maxprint = 3)
  expect_equal(nrow(res$values$details), 10L)
  expect_output(print(res), "3 of 10 differences printed")
})

test_that("print shows all four sections", {
  d <- data.frame(x = 1:2)
  res <- classic_compare(d, d)
  expect_output(print(res), "Data Set Summary")
  expect_output(print(res), "Variables Summary")
  expect_output(print(res), "Observation Summary")
  expect_output(print(res), "Values Comparison Summary")
  expect_output(print(res), "No unequal values were found")
})

test_that("value results show ID values and the return code", {
  b <- data.frame(id = c("A", "B"), x = c(1, 2))
  k <- data.frame(id = c("A", "B"), x = c(1, 3))
  res <- classic_compare(b, k, id = "id")
  expect_output(print(res), "Value Comparison Results for Variables")
  expect_output(print(res), "B +\\|\\|")
  expect_output(print(res), "SYSINFO: 4096")
})

test_that("novalues suppresses the value comparison sections", {
  b <- data.frame(id = c("A", "B"), x = c(1, 2), only_b = 1:2)
  k <- data.frame(id = c("A", "C"), x = c(1, 3), only_c = 1:2)
  res <- classic_compare(b, k, id = "id", novalues = TRUE)

  expect_equal(nrow(res$values$summary), 0L)
  expect_equal(nrow(res$values$details), 0L)
  expect_false("VALUE" %in% res$sysinfo_flags)

  o <- capture.output(print(res))
  expect_false(any(grepl("Values Comparison Summary", o)))
  expect_false(any(grepl("Value Comparison Results", o)))
  expect_true(any(grepl("NOVALUES specified", o)))
  expect_true(any(grepl("Variables Summary", o)))
})

test_that("novalues = FALSE (the default) is unaffected", {
  b <- data.frame(id = c("A", "B"), x = c(1, 2))
  k <- data.frame(id = c("A", "B"), x = c(1, 3))
  res <- classic_compare(b, k, id = "id")

  expect_false(res$novalues)
  expect_true("VALUE" %in% res$sysinfo_flags)
  o <- capture.output(print(res))
  expect_true(any(grepl("Values Comparison Summary", o)))
})
