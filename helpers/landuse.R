# Building density and land use per health area (static).

suppressPackageStartupMessages({library(sf); library(dplyr); library(tidyr)})

# GHS-BUILT-S 2020: built-up surface (m2) per 100 m cell
ghs_built = function(dir = "data/ghs_built") {
	f = list.files(dir, "[.]tif$", full.names = TRUE)
	if (length(f) != 3) stop(dir, " incomplete: run download/ghs_built.R once")
	terra::vrt(f)
}

# OSM land-use classes grouped; shares of each health area's surface
LANDUSE = list(
	lu_residential = "residential",
	lu_commercial = c("commercial", "retail"),
	lu_industrial = c("industrial", "quarry"),
	lu_agricultural = c("farmland", "farmyard", "orchard", "vineyard", "meadow", "allotments"),
	lu_green = c("forest", "scrub", "grass", "heath", "park", "recreation_ground", "nature_reserve")
)

land_use = function(name, areas = area_geometry(name)) {
	area_m2 = as.numeric(st_area(areas))
	ghs = ghs_built()
	built = exactextractr::exact_extract(ghs, st_transform(areas, terra::crs(ghs)),
		"sum", progress = FALSE)
	group = setNames(rep(names(LANDUSE), lengths(LANDUSE)), unlist(LANDUSE))
	lu = osm_layer(name, "gis_osm_landuse_a_free_1",
			where = sprintf("fclass IN (%s)", paste0("'", unlist(LANDUSE), "'", collapse = ", "))) |>
		st_transform(st_crs(areas)) |>
		st_make_valid() |>
		transmute(group = group[fclass]) |>
		st_set_agr("constant")
	# land-use surface inside each health area, by group
	shares = st_intersection(lu, st_set_agr(areas["id"], "constant")) |>
		mutate(m2 = as.numeric(st_area(geometry))) |>
		st_drop_geometry() |>
		count(id, group, wt = m2, name = "m2") |>
		pivot_wider(names_from = group, values_from = m2, values_fill = 0)
	# each building counted once, by its point on surface
	bld = osm_layer(name, "gis_osm_buildings_a_free_1", "osm_id") |>
		st_transform(st_crs(areas)) |>
		st_make_valid() |>
		st_set_agr("constant") |>
		st_point_on_surface() |>
		st_join(areas["id"], join = st_within) |>
		st_drop_geometry() |>
		count(id, name = "n_buildings")
	x = tibble(id = areas$id, area_m2 = area_m2, built_share = built / area_m2) |>
		left_join(shares, by = "id") |>
		left_join(bld, by = "id")
	x[setdiff(names(LANDUSE), names(x))] = 0
	x |>
		mutate(across(all_of(names(LANDUSE)), \(m) pmin(coalesce(m, 0) / area_m2, 1)),   # polygons can overlap
			n_buildings = coalesce(n_buildings, 0L),
			buildings_per_km2 = n_buildings / (area_m2 / 1e6)) |>
		select(id, built_share, n_buildings, buildings_per_km2, all_of(names(LANDUSE)))
}

