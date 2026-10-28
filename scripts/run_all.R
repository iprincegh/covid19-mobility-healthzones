# Rebuilds every output from data/. Run from the repository folder.

if (!dir.exists("helpers")) stop("set the working directory to the repository folder first, e.g. setwd(\"~/covid19-mobility-healthzones\")")

steps = c("1_areas_cases_mobility", "2_census_covariates", "3_osm_landuse", "4_weather", "5_panel_tables")
for (s in steps) {
	message("\n== ", s)
	source(file.path("scripts", paste0(s, ".R")), local = new.env())
}
