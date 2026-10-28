# CatSalut population and COVID-19 vaccination by ABS (Catalunya only).

suppressPackageStartupMessages({library(dplyr); library(tidyr)})

read_catsalut = function(file) {
	f = file.path("data/covariates/raw/catsalut", file)
	if (!file.exists(f)) stop(f, " missing: run download/catsalut.R once")
	read.csv(f, colClasses = c(abs_codi = "character"))
}

# Registered population (RCA) 2021
rca_pop = function() read_catsalut("rca_pop_abs_2021.csv")

# Doses per day, ABS, dose number and brand
vacc_doses = function() read_catsalut("vacc_doses_abs_to_2021-05-01.csv")

# Adds pop and cumulative coverage: vacc_dose1 = at least one dose,
# vacc_complete = two doses or one Janssen. Montcada i Reixac is one ABS (302)
# in CatSalut but two in Flow-Maps: both get its coverage, population split.
add_catsalut = function(panel) {
	pop = rca_pop() |> rename(id = abs_codi)
	doses = vacc_doses()
	# doses with no ABS recorded cannot be placed
	blank = !nzchar(doses$abs_codi)
	if (any(blank)) message("dropping ", sum(doses$n[blank]), " doses with no ABS code")
	doses = doses[!blank, ] |>
		mutate(date = as.Date(substr(data, 1, 10)),
			dose1 = n * (dosi == 1),
			complete = n * (dosi == 2 | grepl("Janssen", fabricant))) |>
		group_by(id = abs_codi, date) |>
		summarise(dose1 = sum(dose1), complete = sum(complete), .groups = "drop")
	lost = setdiff(doses$id, pop$id)
	if (length(lost))
		stop("doses for ABS without RCA population: ", paste(lost, collapse = ", "))

	coverage = expand_grid(id = pop$id, date = sort(unique(panel$date))) |>
		left_join(doses, by = c("id", "date")) |>
		left_join(pop, by = "id") |>
		mutate(across(c(dose1, complete), \(x) coalesce(x, 0))) |>
		group_by(id) |>
		mutate(vacc_dose1 = cumsum(dose1) / pop, vacc_complete = cumsum(complete) / pop) |>
		ungroup() |>
		select(id, date, vacc_dose1, vacc_complete)
	coverage = bind_rows(coverage,
		lapply(MONTCADA, \(m) coverage |> filter(id == "302") |> mutate(id = m)))

	share = montcada_share(panel)
	pop = bind_rows(pop, tibble(id = share$id, pop = pop$pop[pop$id == "302"] * share$s))

	out = panel |>
		left_join(pop, by = "id") |>
		left_join(coverage, by = c("id", "date"))
	stopifnot(!anyNA(out$pop), !anyNA(out$vacc_dose1))
	out
}
