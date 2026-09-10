.PHONY: restore analysis test lint check

restore:
	Rscript -e 'renv::restore(prompt = FALSE)'

analysis:
	Rscript scripts/run_all.R

test:
	Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'

lint:
	Rscript -e 'lints <- unlist(lapply(c("R", "scripts", "tests"), lintr::lint_dir), recursive = FALSE); print(lints); stopifnot(length(lints) == 0L)'

check: analysis test lint
