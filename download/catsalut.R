# CatSalut population and vaccination by ABS into data/covariates/raw/catsalut/.

dir = "data/covariates/raw/catsalut"
dir.create(dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 1800)   # server-side aggregation is slow; default is 60 s

# Fetch a SoQL query as csv
soda = function(id, file, ...) {
	f = file.path(dir, file)
	if (file.exists(f)) return(invisible(f))
	q = c(..., "$limit" = "5000000")
	url = paste0("https://analisi.transparenciacatalunya.cat/resource/", id, ".csv?",
		paste0(names(q), "=", vapply(q, URLencode, "", reserved = TRUE), collapse = "&"))
	download.file(url, tmp <- tempfile(fileext = ".csv"), quiet = TRUE)
	file.rename(tmp, f)
	message("downloaded ", file)
}

# Registered population (RCA) by ABS, 2021
soda("ftq4-h9vk", "rca_pop_abs_2021.csv",
	"$select" = "abs_codi, sum(poblacio_oficial) as pop",
	"$where" = "any = '2021'", "$group" = "abs_codi")

# Vaccine doses per day, ABS, dose number and brand
soda("tp23-dey4", "vacc_doses_abs_to_2021-05-01.csv",
	"$select" = "data, abs_codi, dosi, fabricant, sum(recompte) as n",
	"$where" = "data <= '2021-05-01T00:00:00' and fabricant != 'No administrada'",
	"$group" = "data, abs_codi, dosi, fabricant")
