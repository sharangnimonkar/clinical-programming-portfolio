run <- function(base, cmp, id = NULL, ...) {
  compare_values(base, cmp,
                 compare_variables(base, cmp),
                 match_observations(base, cmp, id = id), ...)
}

test_that("exact comparison flags any difference, diff = compare - base", {
  res <- run(data.frame(x = c(1, 2, 3)), data.frame(x = c(1, 2.5, 3)))
  expect_equal(res$method, "exact")
  expect_equal(res$summary$n_compared, 3L)
  expect_equal(res$summary$n_diff, 1L)
  expect_equal(res$summary$max_abs_diff, 0.5)
  expect_equal(res$details$base_row, 2L)
  expect_equal(res$details$diff, 0.5)
})

test_that("supplying only CRITERION switches to absolute", {
  res <- run(data.frame(x = c(1, 1)), data.frame(x = c(1.05, 1.2)),
             criterion = 0.1)
  expect_equal(res$method, "absolute")
  expect_equal(res$details$base_row, 2L)
})

test_that("relative and percent methods scale by the base value", {
  b <- data.frame(x = 100)
  k <- data.frame(x = 101)
  expect_equal(run(b, k, method = "relative", criterion = 0.05)$summary$n_diff, 0L)
  expect_equal(run(b, k, method = "relative", criterion = 0.005)$summary$n_diff, 1L)
  expect_equal(run(b, k, method = "percent",  criterion = 2)$summary$n_diff, 0L)
  expect_equal(run(b, k, method = "percent",  criterion = 0.5)$summary$n_diff, 1L)
})

test_that("missing numerics: both missing is equal, one missing is unequal", {
  res <- run(data.frame(x = c(NA, NA, 1)), data.frame(x = c(NA, 5, NA)))
  expect_equal(res$details$base_row, 2:3)
})

test_that("character comparison ignores trailing blanks, is case-sensitive, NA equals blank", {
  base <- data.frame(s = c("a ", "B", NA, "x"))
  cmp  <- data.frame(s = c("a",  "b", "", "y"))
  res  <- run(base, cmp)
  expect_equal(res$details$base_row, c(2L, 4L))
  expect_equal(res$details$base_value, c("B", "x"))
  expect_equal(res$details$compare_value, c("b", "y"))
})

test_that("type-mismatched variables are skipped; ID variables are not compared", {
  base <- data.frame(id = c("A", "B"), age = c(30, 40), sex = c("M", "F"))
  cmp  <- data.frame(id = c("B", "A"), age = c("40", "30"), sex = c("F", "F"))
  res  <- run(base, cmp, id = "id")
  expect_equal(res$summary$variable, "sex")
  expect_equal(res$not_compared, "age")
  expect_equal(res$details$base_row, 1L)
  expect_equal(res$details$compare_row, 2L)
})
