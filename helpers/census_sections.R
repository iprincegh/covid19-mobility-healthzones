# Census-section covariates (ADRH 2020, Census 2021) aggregated to health areas.

suppressPackageStartupMessages({
	library(sf); library(dplyr); library(tidyr); library(data.table)
})

SECTIONS = "/vsizip/data/covariates/raw/ine_sections_2020/seccionado_2020.zip/SECC_CE_20200101.shp"

# Section polygons in the health areas' CRS
read_sections = function(areas, provs) {
	stopifnot(inherits(areas, "sf"), !st_is_longlat(areas))
	read_sf(SECTIONS) |>
		filter(substr(CUSEC, 1, 2) %in% provs) |>
		select(cusec = CUSEC) |>
		st_transform(st_crs(areas)) |>     # CRS: sections onto the health areas' UTM
		st_make_valid() |>
		st_set_agr("constant")
}

# cusec -> health area id, by point in polygon
section_lookup = function(areas, provs, sec = read_sections(areas, provs)) {
	# point on surface: a centroid can fall outside its section
	j = st_point_on_surface(sec) |> st_join(areas["id"], join = st_within)
	if (nrow(j) != nrow(sec) || anyNA(j$id))
		stop("sections with no or several areas: ", nrow(j) - nrow(sec), " extra, ", sum(is.na(j$id)), " unassigned")
	if (!all(areas$id %in% j$id))
		stop("areas without sections: ", paste(setdiff(areas$id, j$id), collapse = ", "))
	st_drop_geometry(j)
}

# GHS-POP 2020, 100 m
ghs_pop = function(dir = "data/ghs_pop")
	terra::vrt(list.files(dir, pattern = "\\.tif$", recursive = TRUE, full.names = TRUE))

# Section -> health area weights (1 per section). "population": a straddling section is
# split by where its residents live; "point": all of it to the health area of its point
section_weights = function(areas, provs, rule = c("population", "point"), sec = read_sections(areas, provs)) {
	rule = match.arg(rule)
	if (rule == "point")
		return(section_lookup(areas, provs, sec) |> mutate(w = 1))
	pieces = st_intersection(sec, select(areas, id) |> st_set_agr("constant")) |>
		st_collection_extract("POLYGON")
	ghs = ghs_pop()
	pieces$pop = exactextractr::exact_extract(ghs, st_transform(pieces, terra::crs(ghs)),
		"sum", progress = FALSE)
	pieces$a = as.numeric(st_area(pieces))
	w = st_drop_geometry(pieces) |>
		group_by(cusec, id) |>
		summarise(pop = sum(pop), a = sum(a), .groups = "drop_last") |>
		# no residents on the grid: split by surface
		mutate(w = if (sum(pop) > 0) pop / sum(pop) else a / sum(a)) |>
		ungroup() |>
		filter(w > 0) |>
		select(cusec, id, w)
	if (!all(areas$id %in% w$id))
		stop("areas without sections: ", paste(setdiff(areas$id, w$id), collapse = ", "))
	w
}

# Spanish numbers: "." thousands, "," decimal; suppressed "." becomes NA
num = function(x) suppressWarnings(as.numeric(gsub(",", ".", gsub(".", "", x, fixed = TRUE), fixed = TRUE)))

# Accent-free patterns: the files are UTF-8 with BOM
ADRH = c(
	income_median = "^Mediana de la renta por unidad de consumo",
	gini = "Gini",
	pct65 = "65 y m",
	hh_size = "medio del hogar",
	pop_adrh = "^Poblaci.n$"
)
read_adrh = function(provs, dir = "data/covariates/raw/adrh_2020") {
	files = list.files(dir, full.names = TRUE, pattern = sprintf("^adrh_(%s)_(renta_media_mediana|indice_gini|indicadores_demograficos)_",
		paste(provs, collapse = "|")))
	stopifnot(length(files) == 3 * length(provs))
	x = rbindlist(lapply(files, \(f) fread(f, sep = ";", encoding = "UTF-8", colClasses = "character")[, c(3, 4, 5, 6)]),
			use.names = FALSE) |>
		setNames(c("section", "indicator", "period", "value"))
	x = x[period %in% c("2019", "2020", "2021") & nzchar(section)]
	# suppressed 2020 values take the 2019/2021 mean
	adrh = rbindlist(lapply(names(ADRH), \(v) x[grepl(ADRH[[v]], indicator),
			.(cusec = substr(section, 1, 10), var = v, period, value = num(value))])) |>
		as_tibble() |>
		group_by(cusec, var) |>
		summarise(filled = is.na(value[period == "2020"][1]),
			value = if (filled) mean(value[period != "2020"], na.rm = TRUE) else value[period == "2020"][1],
			.groups = "drop")
	filled = adrh |> filter(filled, !is.na(value)) |> count(var)
	if (nrow(filled))
		message("ADRH 2020 suppressed, filled from 2019/2021: ", paste(filled$var, filled$n, sep = " ", collapse = ", "))
	adrh |> select(-filled) |> pivot_wider(names_from = var, values_from = value)
}

# Census 2021: t2-t16 are shares, t1 and t17-t22 are counts
read_censo = function(provs, f = "data/covariates/raw/ine_censo2021/C2021_Indicadores.csv") {
	read.csv(f, colClasses = "character") |>
		filter(cpro %in% provs) |>
		mutate(cusec = paste0(cpro, cmun, dist, secc), across(matches("^t\\d"), as.numeric)) |>
		select(cusec, matches("^t\\d"))
}

# Weighted sum of num over weighted sum of den, where both are known
ratio = function(num, den, w = 1) {
	ok = !is.na(num) & !is.na(den)
	sum((w * num)[ok]) / sum((w * den)[ok])
}

# One row per health area: counts summed, shares rebuilt as counts over their own
# denominator, each section weighted by w
area_covariates = function(name, rule = "population", areas = area_geometry(name)) {
	provs = region(name)$provs
	section_weights(areas, provs, rule) |>
		left_join(read_adrh(provs), by = "cusec") |>
		left_join(read_censo(provs), by = "cusec") |>
		mutate(pop16 = t1_1 * (1 - t4_1), active = t12_1 * pop16) |>
		group_by(id) |>
		summarise(
			n_sections = n_distinct(cusec),
			pop_census = sum(w * t1_1, na.rm = TRUE),
			income_median = ratio(income_median * pop_adrh, pop_adrh, w),   # median not decomposable: pop-weighted mean
			gini = ratio(gini * pop_adrh, pop_adrh, w),
			pct_65plus = ratio(pct65 / 100 * pop_adrh, pop_adrh, w),
			hh_size = ratio(pop_adrh, pop_adrh / hh_size, w),                # people / households
			pct_foreign = ratio(t5_1 * t1_1, t1_1, w),
			pct_higher_edu = ratio(t9_1 * pop16, pop16, w),
			unemployment = ratio(t10_1 * active, active, w),
			pct_rented = ratio(t20_2, t19_1, w),
			pct_hh5plus = ratio(t22_5, t21_1, w)
		) |>
		left_join(tibble(id = areas$id, km2 = as.numeric(st_area(areas)) / 1e6), by = "id") |>
		mutate(density = pop_census / km2) |>
		select(-km2)
}

# Table name: population rule main, point rule sensitivity
census_table = function(rule = "population") paste0("census_covariates", if (rule == "point") "_point")
