# Step 2: census covariates per health area; main rule "population", "point" as sensitivity.

source("helpers/regions.R")
source("helpers/tables.R")
source("helpers/census_sections.R")

for (name in names(REGIONS)) {
	areas = area_geometry(name)
	for (rule in c("population", "point")) {
		cov = area_covariates(name, rule, areas)
		stopifnot(nrow(cov) == nrow(areas), !anyNA(cov))
		write_table(cov, name, census_table(rule))
	}
}
