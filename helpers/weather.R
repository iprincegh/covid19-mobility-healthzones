# Daily weather per health area: inverse-distance weighted mean of the K nearest AEMET
# stations that reported each variable that day.

suppressPackageStartupMessages({library(sf); library(data.table)})

WEATHER = list(
	cache = "data/covariates/raw/aemet",
	start = "2020-01-01", end = "2022-07-31",   # window plus lead-in for lags
	k = 5, max_km = 75, power = 2,              # stations per health area, search radius, IDW exponent
	vars = c(tmed = "temp_mean", tmin = "temp_min", tmax = "temp_max",   # AEMET name = output name
		prec = "precip", hrMedia = "humidity")
)

aemet_raw_file = function(id) file.path(WEATHER$cache, sprintf("aemet_raw_%s_%s_%s.rds", id, WEATHER$start, WEATHER$end))

# Station series, long: one row per station, day and variable
aemet_long = function() {
	f = list.files(WEATHER$cache, "^aemet_raw_", full.names = TRUE)
	if (!length(f)) stop("no AEMET data in ", WEATHER$cache, ": run download/aemet.R once")
	d = rbindlist(lapply(f, \(x) {
		d = readRDS(x)
		if (is.null(d)) return(NULL)
		d = as.data.table(d)[, intersect(c("fecha", "indicativo", names(WEATHER$vars)), names(d)), with = FALSE]
		for (v in intersect(names(WEATHER$vars), names(d))) {
			x = as.character(d[[v]])
			x[x == "Ip"] = "0"   # inappreciable rain
			set(d, j = v, value = as.numeric(gsub(",", ".", x)))
		}
		d
	}), fill = TRUE)
	d[, fecha := as.Date(fecha)]
	melt(d, id.vars = c("fecha", "indicativo"), variable.factor = FALSE, na.rm = TRUE)
}

# id, date, temp_mean, temp_min, temp_max, precip, humidity, dist_nearest_km
weather_daily = function(name, dl = aemet_long(), a = area_geometry(name)) {
	pt = st_point_on_surface(st_geometry(a))
	st = readRDS(file.path(WEATHER$cache, "stations.rds"))
	ss = st_as_sf(st[st$indicativo %in% unique(dl$indicativo), ], coords = c("longitud", "latitud"), crs = 4326) |>
		st_transform(st_crs(a))   # CRS: stations onto the health areas' UTM
	dmat = matrix(as.numeric(st_distance(pt, ss)), nrow(a)) / 1000   # km
	r = rbindlist(lapply(seq_len(nrow(a)), \(i) {
		near = which(dmat[i, ] <= WEATHER$max_km)
		if (!length(near)) near = which.min(dmat[i, ])
		w = data.table(indicativo = ss$indicativo[near], d = pmax(dmat[i, near], 0.1))
		# per day and variable, the K nearest stations that reported it
		x = dl[w, on = "indicativo", nomatch = NULL][order(d)]
		x[, rk := seq_len(.N), by = .(fecha, variable)]
		x = x[rk <= WEATHER$k, .(value = sum(value / d^WEATHER$power) / sum(1 / d^WEATHER$power)),
			by = .(date = fecha, variable)]
		dcast(x, date ~ variable, value.var = "value")[, `:=`(id = a$id[i], dist_nearest_km = round(min(dmat[i, ]), 2))]
	}), fill = TRUE)
	setnames(r, names(WEATHER$vars), WEATHER$vars)
	setcolorder(r, c("id", "date", WEATHER$vars))
	setorder(r, id, date)
	as.data.frame(r)
}
