test_that("variables are matched case-insensitively and differences flagged", {
  base    <- data.frame(USUBJID = c("A", "B"), AGE = c(30, 40), SEX = c("M", "F"))
  compare <- data.frame(usubjid = c("A", "B"), AGE = c("30", "40"), RACE = c("W", "B"))

  res <- compare_variables(base, compare)

  expect_equal(res$only_base, "SEX")
  expect_equal(res$only_compare, "RACE")
  expect_true(res$common$type_diff[res$common$variable == "AGE"])
  expect_false(res$common$type_diff[res$common$variable == "USUBJID"])
})
