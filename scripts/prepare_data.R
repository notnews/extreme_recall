library(dplyr)
library(readr)
source("R/prepare_survey.R")

survey <- read_csv("data/turk/PartyExemplarsRecode.csv", show_col_types = FALSE)
name_crosswalk <- read_csv("data/reference/name_crosswalk.csv", show_col_types = FALSE)
politician_scores <- read_csv("data/reference/politician_scores.csv", show_col_types = FALSE)
rating_fields <- read_csv("data/reference/rating_fields.csv", show_col_types = FALSE)

responses <- prepare_survey(survey, name_crosswalk, politician_scores, rating_fields)
scored_mentions <- responses |>
  filter(response_type == "free_recall", score_status == "scored")
rated_mentions <- scored_mentions |>
  filter(!is.na(perceived_direction)) |>
  mutate(recall_order = droplevels(recall_order))
scored_partisans <- scored_mentions |>
  filter(party_relation != "independent") |>
  mutate(party_relation = droplevels(party_relation))
rated_partisans <- rated_mentions |>
  filter(party_relation != "independent") |>
  mutate(party_relation = droplevels(party_relation))
