library(estimatr)
library(emmeans)
library(purrr)

models <- list(
  score_mean = lm_robust(
    score_direction ~ 1,
    data = scored_mentions, clusters = respondent_id, se_type = "stata"
  ),
  perception_mean = lm_robust(
    perceived_direction ~ 1,
    data = rated_mentions, clusters = respondent_id, se_type = "stata"
  ),
  score_party_order = lm_robust(
    score_direction ~ party_relation * recall_order,
    data = scored_partisans, clusters = respondent_id, se_type = "stata"
  ),
  perception_party_order = lm_robust(
    perceived_direction ~ party_relation * recall_order,
    data = rated_partisans, clusters = respondent_id, se_type = "stata"
  )
)
coefficients <- map(
  models,
  ~ broom::tidy(.x, conf.int = TRUE) |>
    mutate(mentions = .x$nobs, respondents = .x$nclusters)
) |>
  list_rbind(names_to = "model")
position_means <- models[c("score_party_order", "perception_party_order")] |>
  map(~ emmeans(.x, ~ recall_order | party_relation, df = unique(.x$df)))
position_contrasts <- position_means |>
  map(contrast, method = "trt.vs.ctrl", ref = 1, adjust = "none")
contrasts <- position_contrasts |>
  map(broom::tidy, conf.int = TRUE) |>
  list_rbind(names_to = "model")
interactions <- position_contrasts |>
  map(contrast, method = "revpairwise", by = "contrast", adjust = "none") |>
  map(broom::tidy, conf.int = TRUE) |>
  list_rbind(names_to = "model")

outcomes <- scored_mentions |>
  select(respondent_id, party_relation, recall_order, score_direction, perceived_direction) |>
  tidyr::pivot_longer(ends_with("direction"), names_to = "outcome", values_to = "value") |>
  filter(!is.na(value))
cells <- outcomes |>
  group_by(outcome, party_relation, recall_order) |>
  group_modify(~ broom::tidy(lm_robust(
    value ~ 1,
    data = .x, clusters = respondent_id, se_type = "stata"
  ), conf.int = TRUE) |>
    select(-outcome)) |>
  ungroup()
respondent_means <- outcomes |>
  summarise(value = mean(value), .by = c(outcome, respondent_id))
equal_respondent <- respondent_means |>
  group_by(outcome) |>
  group_modify(~ broom::tidy(
    lm_robust(value ~ 1, data = .x, se_type = "HC1"),
    conf.int = TRUE
  ) |>
    select(-outcome)) |>
  ungroup()
sample_counts <- responses |>
  count(response_type, coding_status, score_status, name = "mentions")
recall_counts <- scored_mentions |>
  count(name, sort = TRUE, name = "mentions")
demographics <- bind_rows(
  mutate(scored_mentions, unit = "mention"),
  scored_mentions |> distinct(respondent_id, .keep_all = TRUE) |> mutate(unit = "respondent")
) |>
  select(unit, age, gender, race, hispanic, educ, respondent_party) |>
  mutate(across(-unit, as.character)) |>
  tidyr::pivot_longer(-unit, names_to = "variable", values_to = "category") |>
  count(unit, variable, category) |>
  mutate(percent = 100 * n / sum(n), .by = c(unit, variable))
