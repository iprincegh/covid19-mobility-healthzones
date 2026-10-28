# Step 4: daily weather per health area, interpolated from AEMET stations.

source("helpers/regions.R")
source("helpers/tables.R")
source("helpers/weather.R")

dl = aemet_long()
for (name in names(REGIONS))
	write_table(weather_daily(name, dl), name, "weather_daily")
