# Step 2: census covariates per BHA; main rule "population", "point" as sensitivity.

source("helpers/regions.R")
source("helpers/tables.R")
source("helpers/census_sections.R")

for (name in names(REGIONS)) {
	bha = bha_geometry(name)
	for (rule in c("population", "point")) {
		cov = bha_covariates(name, rule, bha)
		stopifnot(nrow(cov) == nrow(bha), !anyNA(cov))
		write_table(cov, name, census_table(rule))
	}
}
