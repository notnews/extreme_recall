# Extreme Recall: Which Politicians Come to Mind?

An R analysis of which politicians MTurk respondents recall and how they rate them.

The R workflow fixes source-question links, name coding, score matching, and party groups in the historical analysis. Manuscript interpretation and published exhibits await author review; they contain the historical results.

With R 4.6 installed, run:

```sh
make restore
make check
```

Linux source builds need a C/C++ toolchain and the ICU, libuv, and libxml2 development headers (`libicu-dev`, `libuv1-dev`, and `libxml2-dev` on Debian/Ubuntu), plus `curl`.

`make analysis` runs data preparation and estimation and writes CSV tables and a `knitr::kable()` coefficient table to `results/`. `make test` checks the source links, join invariants, samples, and clustered inference; `make lint` checks R style. `make check` runs all three before freezing a research revision.

[prepare_data.R](scripts/prepare_data.R) reads the survey and reference tables documented below. [analyze.R](scripts/analyze.R) uses `estimatr::lm_robust()` and `emmeans` directly. Coefficients and contrasts use respondent-clustered HC1 covariance with the small-sample correction and t(G−1) inference (`se_type = "stata"` is an R package option; no Stata runtime is used). Position contrasts are unadjusted, and recall order is categorical.

Means weight mentions equally; `equal_respondent.csv` reports the separate estimand that weights respondents equally. Independents remain in descriptive summaries and are excluded from in/out-party regressions. Perception analyses use identified, score-matched names with verified ratings. CF-score inference conditions on the supplied static score estimates. No Senate comparison is produced because the benchmark cannot be verified from the supplied sources.

The original Stata and plotting scripts are available in Git history at `5bb4eb4`.

* [Manuscript](ms/)
* [Tables](tabs/)
* [Figures](figs/)

## Data preparation

The analysis starts from `data/turk/PartyExemplarsRecode.csv` and retains respondents with the supplied eligibility flag `allowed == 1`. Reference tables live in `data/reference/`.

`sources.csv` records SHA-256 hashes of the four archived inputs. Tests verify them and check reference scores against the original score file. The original inputs remain unchanged.

`name_crosswalk.csv` takes the union of response-to-name assignments in the six free-recall slots of `clean_names.dta`, using lowercase and normalized whitespace. It applies those same assignments in every position within each prompted party. Canonical names from the historical coded roster are added where no response key already exists. There are no fuzzy matches or new politician identities. The historical ambiguous response “george bush” continues to map to George W. Bush; this is a coding convention, not a verified identification of the respondent's intent. Unrecognized answers remain unrecognized.

`politician_scores.csv` contains the explicitly named static `cfscore` for the 30 scored politicians in that roster, drawn from `names_scores.dta`. All duplicate records agree on this value after name normalization. The preparation step collapses agreeing duplicates and rejects conflicting scores before its many-to-one join. Politicians without scores remain unscored. Dynamic scores are not used.

`rating_fields.csv` maps the six sliders to the name fields identified in the archived survey export's question labels. Sliders 1–4 rate the first and second free recalls. Sliders 5–6 rate the multiple-choice selections. No slider rates third free recalls. Tests compare every eligible nonblank response's linked rating against the original export inside `survey.zip`.
