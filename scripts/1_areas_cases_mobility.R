# Step 1: health areas, geometry, population, daily cases, mobility and vaccination (Catalunya).

source("helpers/regions.R")
source("helpers/tables.R")
source("helpers/flowmaps_panel.R")
source("helpers/catsalut.R")

for (name in names(REGIONS)) {
	areas = area_geometry(name)
	write_geometry(areas, name)
	write_table(data.frame(id = areas$id, name = areas$name, area_km2 = as.numeric(st_area(areas)) / 1e6),
		name, "areas")

	panel = build_panel(name)
	stopifnot(identical(sort(unique(panel$id)), areas$id))
	panel = if (name == "catalunya") add_catsalut(correct_montcada(panel)) else add_madrid(panel)

	write_table(distinct(panel, id, pop), name, "population")
	write_table(select(panel, id, date, new_cases, total_cases, any_of("reporting")), name, "cases_daily")
	write_table(select(panel, id, date, trips_internal, trips_out, trips_in, total_population, moving_population),
		name, "mobility_daily")
	if (name == "catalunya")
		write_table(select(panel, id, date, vacc_dose1, vacc_complete), name, "vaccination_daily")
}
