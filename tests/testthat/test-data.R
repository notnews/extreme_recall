withr::local_dir(testthat::test_path("../.."))

test_that("joins conserve responses and are independent of input order", {
  expect_equal(nrow(responses), 8 * sum(survey$allowed == 1, na.rm = TRUE))
  expect_false(anyDuplicated(select(responses, respondent_id, name_column)) > 0)
  set.seed(20260910)
  shuffled <- prepare_survey(
    slice_sample(survey, prop = 1), slice_sample(name_crosswalk, prop = 1),
    slice_sample(politician_scores, prop = 1), slice_sample(rating_fields, prop = 1)
  )
  expect_equal(shuffled, responses)
  duplicated_scores <- bind_rows(politician_scores, politician_scores)
  expect_equal(prepare_survey(survey, name_crosswalk, duplicated_scores, rating_fields), responses)
  conflicting_scores <- bind_rows(
    politician_scores, politician_scores |> slice(1) |> mutate(cfscore = cfscore + 1)
  )
  expect_error(prepare_survey(survey, name_crosswalk, conflicting_scores, rating_fields))
  missing_score <- prepare_survey(
    survey, name_crosswalk, slice(politician_scores, -1), rating_fields
  )
  expect_equal(nrow(missing_score), nrow(responses))
  omitted <- filter(missing_score, name == politician_scores$name[1])
  expect_gt(nrow(omitted), 0L)
  expect_true(all(is.na(omitted$cfscore)))
})

test_that("ratings follow the archived question labels", {
  export <- read.csv(unz("data/turk/survey.zip", "survey/orig_data/Party_Exemplars2.csv"))
  for (index in seq_len(nrow(rating_fields))) {
    rating_column <- rating_fields$rating_column[index]
    name_column <- rating_fields$name_column[index]
    expect_match(export[[rating_column]][1], name_column, fixed = TRUE)
    linked <- responses |> filter(.data$name_column == .env$name_column, response_key != "")
    expected <- as.numeric(export[[rating_column]][match(linked$respondent_id, export$V1)])
    expect_equal(linked$rating, expected)
  }
  third_mentions <- responses |> filter(recall_order == "3")
  expect_true(all(is.na(third_mentions$rating)))
  expect_true(all(is.na(third_mentions$perceived_direction)))
  incorrect_fields <- rating_fields
  incorrect_fields$name_column[5:6] <- c("dem_ex_3", "rep_ex_3")
  expect_error(prepare_survey(survey, name_crosswalk, politician_scores, incorrect_fields))
})

test_that("the common dictionary retains old mentions and treats slots alike", {
  historical <- read_csv("data/turk/cleansurvey.csv", show_col_types = FALSE) |>
    transmute(respondent_id = uniqid, recall_party, recall_order = as.character(recall_order))
  revised <- scored_mentions |> mutate(recall_order = as.character(recall_order))
  expect_equal(nrow(anti_join(historical, revised, by = names(historical))), 0L)
  expect_equal(nrow(scored_mentions), 1737L)
  expect_equal(n_distinct(scored_mentions$respondent_id), 344L)
  expect_equal(nrow(rated_mentions), 1202L)
  expect_equal(n_distinct(rated_mentions$respondent_id), 339L)
  newt <- responses |> filter(response_key == "newt gingrich", name_column == "rep_ex_1")
  expect_equal(nrow(newt), 3L)
  expect_true(all(newt$name == "newt gingrich"))
  expect_true(all(is.na(responses$cfscore[responses$coding_status != "identified"])))
  expect_true(all(as.character(scored_mentions$party_relation[
    scored_mentions$respondent_party == "Independent"
  ]) == "independent"))
  expect_false(any(scored_partisans$respondent_party == "Independent"))
})

test_that("reference scores and source files agree with their provenance", {
  sources <- read_csv("data/reference/sources.csv", show_col_types = FALSE)
  hashes <- vapply(sources$path, digest::digest, character(1), algo = "sha256", file = TRUE)
  expect_equal(unname(hashes), sources$sha256)
  source_scores <- readstata13::read.dta13("data/turk/names_scores.dta") |>
    tibble::as_tibble() |>
    transmute(name = normalize_name(name), cfscore) |>
    semi_join(politician_scores, by = "name") |>
    distinct() |>
    arrange(name)
  expect_equal(source_scores$name, arrange(politician_scores, name)$name)
  expect_equal(source_scores$cfscore, arrange(politician_scores, name)$cfscore)
})

test_that("the reference dictionary is the union of historical assignments", {
  coded <- readstata13::read.dta13("data/turk/clean_names.dta")
  historical_aliases <- tidyr::expand_grid(party = c("dem", "rep"), position = 1:3) |>
    purrr::pmap(function(party, position) {
      tibble::tibble(
        recall_party = party,
        response = normalize_name(coded[[paste0(party, "_ex_", position)]]),
        name = normalize_name(coded[[paste0(party, "X", position)]])
      ) |>
        filter(!is.na(name), name != "", response != "")
    }) |>
    purrr::list_rbind() |>
    distinct()
  canonical_names <- historical_aliases |>
    transmute(recall_party, response = name, name) |>
    distinct() |>
    anti_join(historical_aliases, by = join_by(recall_party, response))
  expected <- bind_rows(historical_aliases, canonical_names) |>
    mutate(name = if_else(response == "jeb bush", "jeb bush", name)) |>
    arrange(recall_party, response)
  free_names <- name_crosswalk |>
    filter(response_type == "free_recall") |>
    select(-response_type)
  expect_equal(as.data.frame(free_names), as.data.frame(expected))
})

test_that("prompted selections retain their explicit identities", {
  prompted <- responses |> filter(response_type == "multiple_choice", response_key != "")
  expect_true(all(prompted$coding_status == "identified"))
  jeb <- prompted |> filter(response_key == "jeb bush")
  expect_equal(nrow(jeb), 6L)
  expect_true(all(jeb$name == "jeb bush"))
  source_scores <- readstata13::read.dta13("data/turk/names_scores.dta")
  expect_equal(jeb$cfscore, rep(source_scores$cfscore[source_scores$name == "jeb bush"], 6))
  free_jeb <- responses |> filter(response_type == "free_recall", response_key == "jeb bush")
  expect_equal(nrow(free_jeb), 3L)
  expect_true(all(free_jeb$name == "jeb bush"))
  expect_equal(nrow(prompted_mentions), 633L)
  expect_equal(nrow(pooled_mentions), 1835L)
  expect_false(anyDuplicated(select(pooled_mentions, respondent_id, name_column)) > 0)
})
