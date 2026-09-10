source("scripts/prepare_data.R")
source("scripts/analyze.R")

dir.create("results", showWarnings = FALSE)
tables <- list(
  coefficients = coefficients, contrasts = contrasts, interactions = interactions,
  cells = cells, equal_respondent = equal_respondent, sample_counts = sample_counts,
  recall_counts = recall_counts,
  demographics = demographics
)
purrr::iwalk(tables, ~ readr::write_csv(.x, file.path("results", paste0(.y, ".csv"))))
knitr::kable(coefficients, format = "pipe", digits = 4) |>
  writeLines("results/coefficients.md")
