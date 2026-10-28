# Step 5: calendar, restrictions and the panel tables (main and full).

source("helpers/regions.R")
source("helpers/tables.R")
source("helpers/calendar.R")
source("helpers/restrictions.R")
source("helpers/panel_table.R")

for (name in names(REGIONS)) {
	write_table(calendar_daily(name), name, "calendar_daily")
	write_table(restrictions_daily(name), name, "restrictions_daily")
	write_panel(panel_table(name), name)
}
