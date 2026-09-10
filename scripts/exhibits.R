library(ggplot2)

recall_plot <- ggplot(recall_counts, aes(x = mentions, y = reorder(name, mentions))) +
  geom_point() +
  labs(x = "", y = "") +
  theme_minimal() +
  theme(
    panel.grid.major.y = element_line(colour = "#e3e3e3", linetype = "dotted"),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.x = element_line(colour = "#f1f1f1", linetype = "solid"),
    panel.border = element_blank(), legend.position = "none",
    title = element_text(size = 8), axis.title = element_text(size = 8),
    axis.text = element_text(size = 8, colour = "black"), axis.ticks.y = element_blank(),
    axis.ticks.x = element_line(colour = "#f1f1f1")
  )
ggsave("figs/survey/names_tally.pdf", recall_plot, width = 420 / 72, height = 420 / 72)

perception_table <- coefficients |>
  filter(model %in% c("perception_mean", "prompted_mean", "pooled_mean")) |>
  transmute(
    Sample = recode(model, perception_mean = "Free recall", prompted_mean = "Prompted",
                    pooled_mean = "Both tasks"),
    Ratings = mentions, Respondents = respondents,
    Mean = estimate, `95% CI` = sprintf("[%.3f, %.3f]", conf.low, conf.high)
  )
knitr::kable(perception_table, format = "latex", booktabs = TRUE, digits = 3) |>
  writeLines("tabs/recall.tex")

stage_table <- stage_gaps |>
  transmute(
    Stage = recode(as.character(stage), `1` = "First free recall", `2` = "Second free recall",
                   prompted = "Prompted selection"),
    Gap = estimate, `95% CI` = sprintf("[%.3f, %.3f]", conf.low, conf.high)
  )
knitr::kable(stage_table, format = "latex", booktabs = TRUE, digits = 3) |>
  writeLines("tabs/party_gaps.tex")

score_table <- contrasts |>
  filter(model == "score_party_order") |>
  transmute(
    Party = recode(as.character(party_relation), in_party = "In party", out_party = "Out party"),
    Comparison = recode(contrast, `recall_order2 - recall_order1` = "Second minus first",
                        `recall_order3 - recall_order1` = "Third minus first"),
    Difference = estimate, `95% CI` = sprintf("[%.3f, %.3f]", conf.low, conf.high)
  )
knitr::kable(score_table, format = "latex", booktabs = TRUE, digits = 3) |>
  writeLines("tabs/recall_order.tex")

sample_labels <- tibble::tribble(
  ~command, ~variable, ~category,
  "sampleAgeYoung", "age", "18-29",
  "sampleAgeMiddle", "age", "30-49",
  "sampleAgeOlder", "age", "50+",
  "sampleMale", "gender", "Male",
  "sampleFemale", "gender", "Female",
  "sampleWhite", "race", "White/Caucasian",
  "sampleBlack", "race", "Black/African American",
  "sampleNative", "race", "Native American or Alaska Native",
  "sampleOtherRace", "race", "More than one race",
  "sampleHispanic", "hispanic", "TRUE",
  "sampleHighSchool", "educ", "High school degree or equivalent",
  "sampleCollege", "educ", "Some college",
  "sampleBachelor", "educ", "Bachelor's degree",
  "sampleAdvanced", "educ", "Advanced degree",
  "sampleDemocrat", "respondent_party", "Democrat",
  "sampleRepublican", "respondent_party", "Republican",
  "sampleIndependent", "respondent_party", "Independent"
)
sample_numbers <- demographics |>
  filter(unit == "mention") |>
  inner_join(sample_labels, by = join_by(variable, category), relationship = "one-to-one") |>
  transmute(command, value = sprintf("%.1f", percent))
sample_numbers <- bind_rows(sample_numbers, tibble::tibble(
  command = c("sampleAsianPacific", "sampleLessHighSchool"),
  value = sprintf("%.1f", c(
    100 * mean(scored_mentions$race %in% c("Asian", "Native Hawaiian or other Pacific Islander")),
    100 * mean(scored_mentions$educ == "Less than high school")
  ))
))
analysis_numbers <- tibble::tibble(
  command = c("scoreMentions", "scoreRespondents", "ratedMentions", "ratedRespondents",
              "partisanMentions", "partisanRespondents", "stageMentions", "stageRespondents"),
  value = as.character(c(
    nrow(scored_mentions), n_distinct(scored_mentions$respondent_id),
    nrow(rated_mentions), n_distinct(rated_mentions$respondent_id),
    nrow(scored_partisans), n_distinct(scored_partisans$respondent_id),
    nrow(pooled_partisans), n_distinct(pooled_partisans$respondent_id)
  ))
)
comparison_numbers <- stage_comparisons |>
  mutate(prefix = if_else(contrast1 == "2 - 1", "freeGap", "promptedGap")) |>
  select(prefix, estimate, conf.low, conf.high, p.value) |>
  tidyr::pivot_longer(-prefix) |>
  transmute(
    command = paste0(prefix, recode(name, estimate = "Change", conf.low = "Lower",
                                    conf.high = "Upper", p.value = "P")),
    value = sprintf("%.3f", value)
  )
bind_rows(sample_numbers, analysis_numbers, comparison_numbers) |>
  transmute(line = sprintf("\\newcommand{\\%s}{%s}", command, value)) |>
  pull(line) |>
  writeLines("tabs/numbers.tex")
