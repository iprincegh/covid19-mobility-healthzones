# Area x day panel: Flow-Maps COVID-19 cases joined to MITMA mobility.

suppressPackageStartupMessages({library(arrow); library(dplyr); library(tidyr)})

# Flow-Maps dates are midnight UTC timestamps
utc_date = function(x) as.Date(x, tz = "UTC")

# Negative daily counts (downward revisions) are removed from the preceding
# days, so counts stay non-negative and each BHA total is unchanged
spread_corrections = function(n) {
	for (t in which(n < 0)) {
		need = -n[t]
		n[t] = 0
		for (s in rev(seq_len(t - 1))) {
			take = min(n[s], need)
			n[s] = n[s] - take
			need = need - take
			if (need == 0) break
		}
		if (need > 0) n[t] = -need
	}
	n
}

# Daily trips per BHA: within, leaving, entering
mobility_daily = function(dir) {
	od = open_dataset(dir)
	flow = function(x, key, name) x |>
		select(id = all_of(key), date, trips) |>
		group_by(id, date) |>
		summarise(trips = sum(trips)) |>
		collect() |>
		rename(!!name := trips)
	list(
		od |> filter(source == target) |> flow("source", "trips_internal"),
		od |> filter(source != target) |> flow("source", "trips_out"),
		od |> filter(source != target) |> flow("target", "trips_in")
	) |>
		Reduce(f = \(a, b) full_join(a, b, by = c("id", "date"))) |>
		mutate(date = utc_date(date)) |>
		ungroup() |>
		complete(id, date, fill = list(trips_internal = 0, trips_out = 0, trips_in = 0))
}

# One row per BHA and day of the window
build_panel = function(name, from = WINDOW[1], to = WINDOW[2],
		dir = "data/flowmaps-data") {
	cfg = region(name)
	path = function(x) file.path(dir, paste0(cfg$prefix, x))
	bha = read_sf(path(".geojson")) |> st_drop_geometry()
	cases = read_parquet(path("_covid_cases.parquet")) |>
		mutate(date = utc_date(date)) |>
		select(id, date, new_cases, total_cases) |>
		arrange(id, date)
	neg = cases$new_cases < 0
	if (any(neg))
		message(name, ": ", sum(neg), " negative daily counts (", sum(cases$new_cases[neg]),
			" cases) removed from preceding days")
	cases = cases |>
		group_by(id) |>
		mutate(new_cases = spread_corrections(new_cases)) |>
		ungroup()
	moves = read_parquet(path("_zone_movements.parquet")) |>
		mutate(date = utc_date(date))

	# case ids without geometry (unassigned cases) are dropped
	drop = setdiff(cases$id, bha$id)
	if (length(drop))
		message(name, ": dropping case ids without geometry: ", paste(drop, collapse = ", "),
			" (", sum(cases$new_cases[cases$id %in% drop]), " cases)")

	expand_grid(id = bha$id, date = seq(from, to, by = "day")) |>
		left_join(bha, by = "id") |>
		left_join(cases, by = c("id", "date")) |>
		left_join(mobility_daily(cfg$mobility), by = c("id", "date")) |>
		left_join(moves, by = c("id", "date")) |>
		arrange(id, date)
}

# Montcada i Reixac is one ABS (302) in the official data, two (381, 382) in Flow-Maps
MONTCADA = c("381", "382")

# Each Montcada half's share of residents (MITMA population)
montcada_share = function(panel)
	panel |>
		filter(id %in% MONTCADA) |>
		group_by(id) |>
		summarise(s = mean(total_population)) |>
		mutate(s = s / sum(s))

# Flow-Maps gives 382 the whole of Montcada, and 381 the same plus cases with
# no ABS recorded. Both get the official ABS 302 series instead, split by
# population: 381 the rounded running total, 382 the rest, so they add up to 302.
correct_montcada = function(panel, f = "data/health_data/catalunya/data/covid19_abs_catalunya.csv") {
	official = data.table::fread(f, select = c("TipusCasData", "ABSCodi", "NumCasos"), colClasses = c(ABSCodi = "character")) |>
		filter(ABSCodi == "302") |>
		mutate(date = as.Date(TipusCasData, "%d/%m/%Y")) |>
		group_by(date) |>
		summarise(n = sum(NumCasos))
	s = montcada_share(panel)
	days = tibble(date = sort(unique(panel$date))) |>
		left_join(official, by = "date") |>
		mutate(total = cumsum(coalesce(n, 0L)), part = round(total * s$s[s$id == "381"]))
	split = bind_rows(transmute(days, id = "381", date, total_cases = part),
			transmute(days, id = "382", date, total_cases = total - part)) |>
		group_by(id) |>
		mutate(new_cases = diff(c(0, total_cases))) |>
		ungroup()
	rows_update(panel, split, by = c("id", "date"))
}

# Madrid population: padron 2019, from the official ZBS boundaries
zbs_population = function(f = "data/health_data/madrid/boundaries/zonas_basicas_salud/zonas_basicas_salud.shp")
	read_sf(f) |> st_drop_geometry() |> select(id = codigo_geo, pop = pob_pad19)

# Madrid: population, and reporting (weekly totals from 2020-07-07)
add_madrid = function(panel)
	panel |>
		left_join(zbs_population(), by = "id") |>
		mutate(reporting = if_else(date <= as.Date("2020-07-01"), "daily", "weekly"))
