# Regional restrictions (NPIs), 0/1 per day, from the decrees
NPI = data.frame(
	measure = c("npi_alarm", "npi_alarm", "npi_hibernation", "npi_curfew", "npi_curfew"),
	label = c("First state of alarm", "Second state of alarm", "Non-essential work suspended", "Curfew", "Curfew"),
	region = c("ES", "ES", "ES", "CT", "MD"),
	start = as.Date(c("2020-03-14", "2020-10-25", "2020-03-30", "2020-10-25", "2020-10-25")),
	end = as.Date(c("2020-06-20", "2021-05-09", "2020-04-09", "2021-05-09", "2021-05-09")),
	source = c(
		"RD 463/2020 and extensions (ended 21-06 00:00)",
		"RD 926/2020, extended by RD 956/2020",
		"RDL 10/2020",
		"22:00-06:00, Resolucio SLT/2620/2020 (Generalitat de Catalunya)",
		"00:00, Decreto 29/2020; 23:00 from 2021-01-18, Decreto 3/2021; 22:00 from 2021-01-25, Decreto 4/2021 (Comunidad de Madrid)")
)

add_restrictions = function(x, name) {
	r = NPI[NPI$region %in% c("ES", region(name)$code), ]
	for (m in unique(r$measure)) {
		s = r[r$measure == m, ]
		x[[m]] = as.integer(Reduce(`|`, Map(\(a, b) x$date >= a & x$date <= b, s$start, s$end)))
	}
	x
}

# One row per day: date, npi_*
restrictions_daily = function(name) add_restrictions(data.frame(date = seq(WINDOW[1], WINDOW[2], by = "day")), name)
