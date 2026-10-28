# Panel tables: the per-source tables joined into one row per health area and day.

suppressPackageStartupMessages({library(arrow); library(dplyr)})

# Main table: one variable per collinear group (static covariates VIF < 5);
# the others stay in the full table (see SCHEMA.md)
MAIN = c("id", "date", "name", "new_cases", "total_cases", "reporting", "pop",
	"trips_internal", "trips_out", "moving_population", "vacc_dose1",
	"temp_mean", "precip", "humidity", "dow", "holiday",
	"npi_alarm", "npi_hibernation", "npi_curfew",
	"income_median", "gini", "pct_65plus", "hh_size", "pct_foreign",
	"built_share", "lu_commercial", "lu_industrial", "lu_agricultural", "lu_green",
	"poi_retail", "poi_transport", "poi_education", "poi_religious", "poi_buildings", "poi_health")

# Tables by key (vaccination: Catalunya only)
DAILY = c("mobility_daily", "vaccination_daily", "weather_daily")       # id + date
STATIC = c("areas", "population", "census_covariates", "osm_pois", "landuse")   # id
REGION_DAILY = c("calendar_daily", "restrictions_daily")                # date

panel_table = function(name) {
	t = \(what) read_table(name, what)
	x = t("cases_daily")
	for (w in DAILY[file.exists(table_file(name, DAILY))]) x = left_join(x, t(w), by = c("id", "date"))
	for (w in STATIC) x = left_join(x, t(w), by = "id")
	for (w in REGION_DAILY) x = left_join(x, t(w), by = "date")
	x = x |>
		select(-n_sections) |>
		mutate(dow = factor(dow, DOW)) |>
		relocate(id, date, name, new_cases, total_cases, any_of("reporting"), pop) |>
		arrange(id, date)
	stopifnot(nrow(x) == nrow(t("cases_daily")), !anyNA(x))
	x
}

# _main_noncollinear: MAIN columns; _full_allcovariates: every column
write_panel = function(x, name, dir = out_dir(name, "panel")) {
	dir.create(dir, recursive = TRUE, showWarnings = FALSE)
	f = file.path(dir, region(name)$out)
	main = select(x, any_of(MAIN))
	for (t in list(list(main, paste0(f, "_main_noncollinear")), list(x, paste0(f, "_full_allcovariates")))) {
		write_parquet(t[[1]], paste0(t[[2]], ".parquet"))
		write.csv(t[[1]], paste0(t[[2]], ".csv"), row.names = FALSE)
		message("wrote ", basename(t[[2]]), ": ", nrow(t[[1]]), " rows x ", ncol(t[[1]]), " columns")
	}
}
