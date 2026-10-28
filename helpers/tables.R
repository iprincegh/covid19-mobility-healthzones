# Per-source tables, one csv per region and source, keyed by id, id + date or date.

suppressPackageStartupMessages({library(sf); library(dplyr)})

# outputs/<region>/{tables,panel,geometry}
out_dir = function(name, what) file.path("outputs", name, what)

table_file = function(name, what) file.path(out_dir(name, "tables"), paste0(region(name)$out, "_", what, ".csv"))

write_table = function(x, name, what) {
	key = intersect(c("id", "date"), names(x))
	stopifnot(length(key) > 0, !anyDuplicated(x[key]))
	dir.create(out_dir(name, "tables"), recursive = TRUE, showWarnings = FALSE)
	write.csv(x, table_file(name, what), row.names = FALSE)
	message("wrote ", basename(table_file(name, what)), ": ", nrow(x), " rows, key ", paste(key, collapse = " + "))
}

# id stays text ("001"), date stays Date
read_table = function(name, what) {
	f = table_file(name, what)
	if (!file.exists(f)) stop(f, " missing: run the scripts/ step that writes it")
	cc = c(id = "character", date = "Date")
	read.csv(f, colClasses = cc[intersect(names(cc), names(read.csv(f, nrows = 0)))])
}

# UTM polygons as gpkg, adjacency and distances as rds
write_geometry = function(g, name) {
	dir.create(out_dir(name, "geometry"), recursive = TRUE, showWarnings = FALSE)
	f = file.path(out_dir(name, "geometry"), region(name)$out)
	st_write(g, paste0(f, ".gpkg"), delete_dsn = TRUE, quiet = TRUE)
	saveRDS(area_topology(g), paste0(f, "_topology.rds"))
	message("wrote ", basename(f), ".gpkg + _topology.rds: ", nrow(g), " areas, ", st_crs(g)$input)
}
