# National and regional public holidays in the window, from the official
# calendars (DOGC, BOCM); municipal holidays not included.
HOLIDAYS = rbind(
	data.frame(region = "ES", date = c("2020-04-10", "2020-05-01", "2020-08-15", "2020-10-12",
		"2020-12-08", "2020-12-25", "2021-01-01", "2021-01-06", "2021-04-02", "2021-05-01")),
	data.frame(region = "CT", date = c("2020-04-13", "2020-06-24", "2020-09-11", "2020-12-26", "2021-04-05")),
	data.frame(region = "MD", date = c("2020-04-09", "2020-05-02", "2020-11-02", "2020-12-07",
		"2021-03-19", "2021-04-01"))
) |> transform(date = as.Date(date))

DOW = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

add_calendar = function(x, name) {
	h = HOLIDAYS$date[HOLIDAYS$region %in% c("ES", region(name)$code)]
	x |> mutate(dow = factor(weekdays(date, abbreviate = TRUE), DOW),
		holiday = date %in% h)
}

# One row per day: date, dow, holiday
calendar_daily = function(name) add_calendar(data.frame(date = seq(WINDOW[1], WINDOW[2], by = "day")), name)
