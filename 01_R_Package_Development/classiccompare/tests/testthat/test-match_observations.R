test_that("no ID or BY matches by position", {
  res <- match_observations(data.frame(x = 1:3), data.frame(x = 1:4))
  expect_equal(res$matched$base_row, 1:3)
  expect_equal(res$matched$compare_row, 1:3)
  expect_equal(res$only_base, integer(0))
  expect_equal(res$only_compare, 4L)
})

test_that("ID matching ignores row order and finds unmatched rows", {
  base    <- data.frame(id = c("A", "B", "C"))
  compare <- data.frame(id = c("C", "A", "D"))
  res <- match_observations(base, compare, id = "id")
  expect_equal(res$matched$base_row, c(1L, 3L))
  expect_equal(res$matched$compare_row, c(2L, 1L))
  expect_equal(res$only_base, 2L)
  expect_equal(res$only_compare, 3L)
})

test_that("duplicate IDs are paired in order of appearance", {
  base    <- data.frame(id = c("A", "A", "B"))
  compare <- data.frame(id = c("A", "B", "A", "A"))
  res <- match_observations(base, compare, id = "id")
  expect_equal(res$matched$compare_row, c(1L, 3L, 2L))
  expect_equal(res$only_compare, 4L)
})

test_that("BY matches by position within each group", {
  base    <- data.frame(grp = c("X", "X", "Y"))
  compare <- data.frame(grp = c("X", "Y", "Y"))
  res <- match_observations(base, compare, by = "grp")
  expect_equal(res$matched$base_row, c(1L, 3L))
  expect_equal(res$matched$compare_row, c(1L, 2L))
  expect_equal(res$only_base, 2L)
  expect_equal(res$only_compare, 3L)
})

test_that("ID names are case-insensitive; bad ID variables error", {
  base    <- data.frame(USUBJID = c("A", "B"))
  compare <- data.frame(usubjid = c("B", "A"))
  res <- match_observations(base, compare, id = "usubjid")
  expect_equal(res$n_common, 2L)

  expect_error(match_observations(base, compare, id = "nope"), "not in base")
  expect_error(
    match_observations(data.frame(id = 1:2), data.frame(id = c("1", "2")), id = "id"),
    "differ in type"
  )
})
