# Region settings and BHA geometry, defined once for every script.

suppressPackageStartupMessages({library(sf); library(dplyr)})

# Study window: every daily table covers these days
WINDOW = as.Date(c("2020-03-01", "2021-05-01"))

# CRS: each region's own UTM zone, so surface areas, distances and joins are in metres
REGIONS = list(
	catalunya = list(prefix = "abs_09", crs = 25831, provs = c("08", "17", "25", "43"),
		mobility = "data/cat_od_bha_reprojected", out = "cat_abs", unit = "ABS",
		osm = "cataluna-latest-free.shp.zip", code = "CT",
		aemet = c("BARCELONA", "GIRONA", "LLEIDA", "TARRAGONA")),
	madrid = list(prefix = "zon_bas_13", crs = 25830, provs = "28",
		mobility = "data/mad_od_bha_reprojected", out = "mad_zbs", unit = "ZBS",
		osm = "madrid-latest-free.shp.zip", code = "MD",
		aemet = "MADRID")
)

region = function(name) {
	if (is.null(REGIONS[[name]])) stop("unknown region: ", name)
	REGIONS[[name]]
}

# BHAs in UTM, ordered by id
bha_geometry = function(name, dir = "data/flowmaps-data") {
	cfg = region(name)
	read_sf(file.path(dir, paste0(cfg$prefix, ".geojson"))) |>
		st_transform(cfg$crs) |>
		st_make_valid() |>
		arrange(id)
}

# Queen adjacency (binary) and distances (km), for any spatial model
bha_topology = function(g, snap = 1) {
	stopifnot(inherits(g, "sf"), !st_is_longlat(g))
	# snap 1 m closes floating-point gaps between neighbours
	nb = spdep::poly2nb(g, queen = TRUE, snap = snap)
	if (spdep::n.comp.nb(nb)$nc > 1)
		stop("neighbour graph is not connected at snap = ", snap, " m")
	adj = spdep::nb2mat(nb, style = "B", zero.policy = TRUE)
	dimnames(adj) = list(g$id, g$id)
	# point on surface: a centroid can fall outside its polygon
	dist_km = st_point_on_surface(st_geometry(g)) |> st_distance() |> as.numeric() / 1000
	list(adjacency = adj, dist_km = matrix(dist_km, nrow(g), dimnames = dimnames(adj)))
}

