# AEMET daily station data into data/covariates/raw/aemet/. Needs an AEMET API key.

suppressPackageStartupMessages({library(climaemet); library(data.table)})
source("helpers/regions.R")
source("helpers/weather.R")      # WEATHER settings, aemet_raw_file()

if (!nzchar(Sys.getenv("AEMET_API_KEY"))) stop("set AEMET_API_KEY for this session first")
dir.create(WEATHER$cache, recursive = TRUE, showWarnings = FALSE)

f_st = file.path(WEATHER$cache, "stations.rds")
if (!file.exists(f_st)) saveRDS(aemet_stations(), f_st)
st = as.data.table(readRDS(f_st))[toupper(trimws(provincia)) %in% unlist(lapply(REGIONS, `[[`, "aemet"))]

# failed requests are not saved, so a rerun retries them
for (id in st$indicativo[!file.exists(aemet_raw_file(st$indicativo))]) {
	Sys.sleep(1.2)   # AEMET rate limit
	d = try(aemet_daily_clim(station = id, start = WEATHER$start, end = WEATHER$end,
		return_sf = FALSE, verbose = FALSE), silent = TRUE)
	if (inherits(d, "try-error")) { message(id, " failed, rerun later"); next }
	saveRDS(if (!is.null(d) && nrow(d)) d, aemet_raw_file(id))
}
message(sum(file.exists(aemet_raw_file(st$indicativo))), " of ", nrow(st), " stations cached")
