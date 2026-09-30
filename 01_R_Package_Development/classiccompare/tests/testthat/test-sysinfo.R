test_that("identical datasets return 0", {
  d <- data.frame(id = 1:3, x = c(1, 2, 3))
  res <- classic_compare(d, d, id = "id")
  expect_equal(sysinfo(res), 0L)
  expect_equal(res$sysinfo_flags, character(0))
})

test_that("unequal values set VALUE", {
  b <- data.frame(id = c("A", "B"), x = c(1, 2))
  k <- data.frame(id = c("A", "B"), x = c(1, 3))
  expect_equal(sysinfo(classic_compare(b, k, id = "id")), 4096L)
})

test_that("unmatched observations set BASEOBS and COMPOBS", {
  b <- data.frame(id = c("A", "B", "C"), x = c(1, 2, 3))
  k <- data.frame(id = c("C", "A", "D"), x = c(3, 1.5, 9))
  res <- classic_compare(b, k, id = "id")
  expect_equal(sysinfo(res), 64L + 128L + 4096L)
  expect_equal(sysinfo_decode(sysinfo(res)), c("BASEOBS", "COMPOBS", "VALUE"))
})

test_that("variables in one dataset only set BASEVAR and COMPVAR", {
  b <- data.frame(id = 1:2, a = 1:2)
  k <- data.frame(id = 1:2, b = 1:2)
  expect_equal(sysinfo(classic_compare(b, k)), 1024L + 2048L)
})

test_that("type mismatch sets TYPE", {
  b <- data.frame(x = c(1, 2))
  k <- data.frame(x = c("1", "2"))
  expect_equal(sysinfo(classic_compare(b, k)), 8192L)
})

test_that("label and format differences set LABEL and FORMAT", {
  b <- data.frame(x = 1:2)
  k <- b
  attr(b$x, "label") <- "Age"
  attr(k$x, "label") <- "Age in years"
  expect_equal(sysinfo(classic_compare(b, k)), 32L)

  attr(b$x, "format.sas") <- "BEST8."
  expect_equal(sysinfo(classic_compare(b, k)), 32L + 8L)
})

test_that("BY groups present in only one dataset set BASEBY and COMPBY", {
  b <- data.frame(g = c("X", "Y"), x = 1:2)
  k <- data.frame(g = c("X", "Z"), x = 1:2)
  res <- classic_compare(b, k, by = "g")
  expect_equal(sysinfo(res), 256L + 512L + 64L + 128L)
})

test_that("sysinfo_decode handles 0 and multiple bits", {
  expect_equal(sysinfo_decode(0L), character(0))
  expect_equal(sysinfo_decode(4096L + 32L), c("LABEL", "VALUE"))
})

test_that("the return code is shown in the printed report", {
  d <- data.frame(x = 1:2)
  expect_output(print(classic_compare(d, d)), "SYSINFO: 0")
})
