withr::local_dir(testthat::test_path("../.."))

test_that("standard estimators reproduce independent clustered inference", {
  source("scripts/analyze.R", local = TRUE)
  reference <- lm(perceived_direction ~ party_relation * recall_order, data = rated_partisans)
  covariance <- sandwich::vcovCL(reference, cluster = rated_partisans$respondent_id, type = "HC1")
  reference_test <- lmtest::coeftest(
    reference,
    vcov. = covariance, df = n_distinct(rated_partisans$respondent_id) - 1
  )
  fitted <- coefficients |> filter(model == "perception_party_order")
  expect_equal(fitted$estimate, unname(coef(reference)), tolerance = 1e-10)
  expect_equal(fitted$std.error, sqrt(unname(diag(covariance))), tolerance = 1e-10)
  expect_equal(fitted$p.value, unname(reference_test[, 4]), tolerance = 1e-10)
  interaction <- interactions |> filter(model == "perception_party_order")
  expect_equal(interaction$estimate, tail(fitted$estimate, 1), tolerance = 1e-10)
  expect_equal(interaction$std.error, tail(fitted$std.error, 1), tolerance = 1e-10)
  expect_equal(interaction$df, tail(fitted$df, 1))
  expect_equal(interaction$p.value, tail(fitted$p.value, 1), tolerance = 1e-10)
  expected_mean <- mean(rated_mentions$perceived_direction)
  expect_equal(models$perception_mean$coefficients[[1]], expected_mean, tolerance = 1e-10)
  for (model in models) {
    expect_equal(model$rank, model$k)
    expect_true(all(is.finite(model$std.error)))
  }
  set.seed(17)
  shuffled_model <- estimatr::lm_robust(
    perceived_direction ~ party_relation * recall_order,
    data = slice_sample(rated_partisans, prop = 1), clusters = respondent_id, se_type = "stata"
  )
  expect_equal(shuffled_model$coefficients, models$perception_party_order$coefficients)
  expect_equal(shuffled_model$vcov, models$perception_party_order$vcov)
})

test_that("prompted comparisons use respondent inference and preserve stage identities", {
  source("scripts/analyze.R", local = TRUE)
  reference <- lm(perceived_direction ~ party_relation * stage, data = pooled_partisans)
  covariance <- sandwich::vcovCL(reference, cluster = pooled_partisans$respondent_id, type = "HC1")
  reference_test <- lmtest::coeftest(
    reference, vcov. = covariance, df = n_distinct(pooled_partisans$respondent_id) - 1
  )
  fitted <- coefficients |> filter(model == "perception_party_stage")
  expect_equal(fitted$estimate, unname(coef(reference)), tolerance = 1e-10)
  expect_equal(fitted$std.error, sqrt(unname(diag(covariance))), tolerance = 1e-10)
  expect_equal(stage_comparisons$estimate, tail(fitted$estimate, 2), tolerance = 1e-10)
  expect_equal(stage_comparisons$p.value, unname(tail(reference_test[, 4], 2)), tolerance = 1e-10)
  expect_true(all(stage_comparisons$df == n_distinct(pooled_partisans$respondent_id) - 1))
  expect_equal(models$pooled_mean$coefficients[[1]], mean(pooled_mentions$perceived_direction))
  expect_equal(
    models$perception_mean$coefficients[[1]], mean(rated_mentions$perceived_direction)
  )
})
