normalize_name <- function(name) {
  stringr::str_to_lower(stringr::str_squish(name), locale = "en")
}

prepare_survey <- function(survey, name_crosswalk, politician_scores, rating_fields) {
  stopifnot(!anyDuplicated(survey$uniqid))
  name_crosswalk <- name_crosswalk |>
    mutate(across(c(response, name), normalize_name))
  stopifnot(!anyDuplicated(select(name_crosswalk, recall_party, response)))
  politician_scores <- politician_scores |>
    transmute(name = normalize_name(name), cfscore) |>
    distinct()
  stopifnot(
    !anyNA(politician_scores), all(nzchar(politician_scores$name)),
    all(is.finite(politician_scores$cfscore)), !anyDuplicated(politician_scores$name)
  )
  expected_fields <- c("dem_ex_1", "rep_ex_1", "dem_ex_2", "rep_ex_2", "dem_ex_mc", "rep_ex_mc")
  rating_fields <- arrange(rating_fields, rating_column)
  stopifnot(
    nrow(rating_fields) == 6L,
    identical(rating_fields$rating_column, paste0("libcon_", 1:6)),
    identical(rating_fields$name_column, expected_fields)
  )
  respondents <- survey |>
    filter(allowed == 1) |>
    rename(respondent_id = uniqid, respondent_party = pid3)
  stopifnot(all(respondents$respondent_party %in% c("Democrat", "Republican", "Independent")))
  ratings <- respondents |>
    select(respondent_id, all_of(rating_fields$rating_column)) |>
    tidyr::pivot_longer(-respondent_id, names_to = "rating_column", values_to = "rating") |>
    left_join(rating_fields, by = "rating_column", relationship = "many-to-one")
  stopifnot(all(is.na(ratings$rating) | between(ratings$rating, 1, 7)))

  respondents |>
    select(
      respondent_id, respondent_party, age, gender, race, hispanic, educ,
      matches("^(dem|rep)_ex_([123]|mc)$")
    ) |>
    tidyr::pivot_longer(
      matches("^(dem|rep)_ex_([123]|mc)$"),
      names_to = "name_column", values_to = "response"
    ) |>
    mutate(
      recall_party = stringr::str_sub(name_column, 1, 3),
      position = stringr::str_remove(name_column, "^(dem|rep)_ex_"),
      response_type = if_else(position == "mc", "multiple_choice", "free_recall"),
      recall_order = factor(position, levels = c("1", "2", "3")),
      response_key = normalize_name(coalesce(response, ""))
    ) |>
    left_join(
      name_crosswalk,
      by = join_by(recall_party, response_key == response),
      relationship = "many-to-one"
    ) |>
    left_join(politician_scores, by = "name", relationship = "many-to-one") |>
    left_join(ratings, by = join_by(respondent_id, name_column), relationship = "one-to-one") |>
    mutate(
      coding_status = case_when(
        response_key == "" ~ "blank",
        is.na(name) ~ "unrecognized",
        .default = "identified"
      ),
      rating = if_else(response_key == "", NA_real_, rating),
      score_status = if_else(is.na(cfscore), "unscored", "scored"),
      score_direction = if_else(recall_party == "dem", -cfscore, cfscore),
      perceived_direction = if_else(recall_party == "dem", (7 - rating) / 6, (rating - 1) / 6),
      party_relation = case_when(
        respondent_party == "Independent" ~ "independent",
        respondent_party == "Democrat" & recall_party == "dem" ~ "in_party",
        respondent_party == "Republican" & recall_party == "rep" ~ "in_party",
        .default = "out_party"
      ),
      party_relation = factor(party_relation, levels = c("in_party", "out_party", "independent"))
    ) |>
    select(-position) |>
    arrange(respondent_id, name_column)
}
