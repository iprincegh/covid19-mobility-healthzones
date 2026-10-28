# Step 3: OSM points of interest and health facilities, building density and land use.

source("helpers/regions.R")
source("helpers/tables.R")
source("helpers/osm.R")
source("helpers/landuse.R")

for (name in names(REGIONS)) {
	areas = area_geometry(name)
	write_table(osm_counts(name, areas), name, "osm_pois")
	write_table(land_use(name, areas), name, "landuse")
}
