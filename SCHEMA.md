# COVID-19 panel tables by basic health area: schema

One table per region, one row per basic health area (BHA) and day, 2020-03-01 →
2021-05-01 (427 days). Key: `id` + `date`. The BHAs are ABS in Catalunya and ZBS in Madrid.

| Table | Basic health areas | Rows | Columns |
|---|---|---|---|
| `outputs/catalunya/panel/cat_abs_main_noncollinear` | 374 ABS | 159,698 | 34 |
| `outputs/catalunya/panel/cat_abs_full_allcovariates` | 374 ABS | 159,698 | 56 |
| `outputs/madrid/panel/mad_zbs_main_noncollinear` | 286 ZBS | 122,122 | 34 |
| `outputs/madrid/panel/mad_zbs_full_allcovariates` | 286 ZBS | 122,122 | 55 |

**Main table (`*_main_noncollinear`)**: static covariates have VIF < 5.

- **keys and outcome:** `id`, `date`, `name`, `new_cases`, `total_cases`, `pop`, `reporting` (Madrid)
- **daily:** `trips_internal`, `trips_out`, `moving_population`, `vacc_dose1` (Catalunya),
  `temp_mean`, `precip`, `humidity`, `dow`, `holiday`, `npi_alarm`, `npi_hibernation`, `npi_curfew`
- **static:** `income_median`, `gini`, `pct_65plus`, `hh_size`, `pct_foreign`, `built_share`,
  `lu_commercial`, `lu_industrial`, `lu_agricultural`, `lu_green`, `poi_retail`, `poi_transport`,
  `poi_education`, `poi_religious`, `poi_buildings`, `poi_health`

**Full table (`*_full_allcovariates`)**: all columns below. Columns not in the main table:

| Left out | Collinear with |
|---|---|
| `pct_higher_edu`, `unemployment` | `income_median` |
| `pct_hh5plus` | `hh_size` |
| `pct_rented` | urbanisation (`built_share`, `pct_foreign`) |
| `density`, `area_km2`, `buildings_per_km2`, `n_buildings`, `lu_residential` | `built_share` |
| `poi_food`, `poi_essential` | `poi_retail` |
| `poi_recreation` | `built_share` |
| `poi_industrial` | `lu_industrial` (same OSM polygons) |
| `poi_other`, `n_pharmacy` | `area_km2`, `poi_essential` |
| `pop_census` | `pop` |
| `trips_in` | `trips_out` (near-identical) |
| `total_population` | `moving_population` |
| `temp_min`, `temp_max` | `temp_mean` |
| `vacc_complete` | `vacc_dose1` |
| `dist_nearest_km` | not a covariate: distance to the nearest weather station |

## Columns

Each column comes from one table in `outputs/<region>/tables/` (`cat_abs_*`, `mad_zbs_*`).

### Keys, outcome and population

| Column | Type | Content | Source | Table |
|---|---|---|---|---|
| `id` | chr | BHA code, 3 characters (`"001"`): the official ABS code (`ABSCodi`, Catalunya) or ZBS `codigo_geo` (Madrid), zero-padded; 381 and 382 are the two Flow-Maps halves of Montcada i Reixac (official ABS 302) | Flow-Maps | every table |
| `date` | Date | day | | every daily table |
| `name` | chr | BHA name | Flow-Maps | `*_areas` |
| `area_km2` | num | surface, km² | | `*_areas` |
| `new_cases` | int | confirmed cases; corrections in the README | Flow-Maps; 381, 382 official (README) | `*_cases_daily` |
| `total_cases` | int | cumulative cases from 2020-03-01 | as `new_cases` | `*_cases_daily` |
| `reporting` *(Madrid)* | chr | `daily` to 2020-07-01, then `weekly`: weekly totals, mostly on Tuesdays from 2020-07-07 | Flow-Maps | `*_cases_daily` |
| `pop` | num | residents: RCA 2021 (Catalunya), padrón 2019 (Madrid) | CatSalut, Comunidad de Madrid | `*_population` |

### Daily

| Column | Type | Content | Source | Table |
|---|---|---|---|---|
| `trips_internal`, `trips_out`, `trips_in` | num | trips within, out of, into the BHA | MITMA, projected onto BHAs (Zenodo, README) | `*_mobility_daily` |
| `total_population`, `moving_population` | num | MITMA population; people making ≥ 1 trip | Flow-Maps | `*_mobility_daily` |
| `vacc_dose1`, `vacc_complete` *(Catalunya)* | num | share with ≥ 1 dose; share fully vaccinated | CatSalut | `*_vaccination_daily` |
| `temp_mean`, `temp_min`, `temp_max` | num | daily temperature, °C | AEMET | `*_weather_daily` |
| `precip` | num | daily precipitation (rain and melted snow), mm | AEMET | `*_weather_daily` |
| `humidity` | num | daily mean relative humidity, % | AEMET | `*_weather_daily` |
| `dist_nearest_km` | num | distance to the nearest weather station | AEMET | `*_weather_daily` |
| `dow` | factor | day of week | | `*_calendar_daily` |
| `holiday` | lgl | national or regional public holiday | DOGC, BOCM | `*_calendar_daily` |
| `npi_alarm` | 0/1 | first state of alarm (2020-03-14 → 06-20) or second state of alarm (2020-10-25 → 2021-05-09) | RD 463/2020, RD 926/2020 (citations in README) | `*_restrictions_daily` |
| `npi_hibernation` | 0/1 | non-essential work suspended (2020-03-30 → 04-09) | RDL 10/2020 | `*_restrictions_daily` |
| `npi_curfew` | 0/1 | curfew (from 2020-10-25) | Resolució SLT/2620/2020 (Catalunya); Decretos 29/2020, 3/2021, 4/2021 (Madrid) | `*_restrictions_daily` |

Restrictions are coded per region, the same for every BHA.

### Static per BHA

**Census covariates** (`*_census_covariates`; INE ADRH 2020, Census 2021), aggregated
from census sections as described in the README.

| Column | Content |
|---|---|
| `pop_census` | residents, Census 2021 |
| `income_median` | median income per consumption unit, EUR |
| `gini` | Gini index, 0–100 |
| `pct_65plus`, `pct_foreign`, `pct_higher_edu`, `unemployment`, `pct_rented`, `pct_hh5plus` | shares, 0–1 |
| `hh_size` | people per household |
| `density` | people per km² |

**Points of interest and health facilities** (`*_osm_pois`; OpenStreetMap, Geofabrik
extracts): counts of features in each BHA. A polygon counts as one feature; a
feature mapped twice counts once.

| Column | Category | `fclass` → OSM tag |
|---|---|---|
| `poi_retail` | Retail and trade | `supermarket` shop=supermarket · `convenience` shop=convenience · `clothes` shop=clothes · `bakery` shop=bakery · `butcher` shop=butcher · `greengrocer` shop=greengrocer · `shoe_shop` shop=shoes · `jeweller` shop=jewelry · `beverages` shop=alcohol, shop=beverages · `bookshop` shop=books · `gift_shop` shop=gift · `florist` shop=florist · `mobile_phone_shop` shop=mobile_phone · `bicycle_shop` shop=bicycle · `doityourself` shop=doityourself, shop=hardware · `furniture_shop` shop=furniture · `computer_shop` shop=computer · `sports_shop` shop=sports · `kiosk` shop=kiosk · `stationery` shop=stationery · `toy_shop` shop=toys · `newsagent` shop=newsagent · `garden_centre` shop=garden_centre · `outdoor_shop` shop=outdoor · `department_store` shop=department_store · `general` shop=general · `mall` shop=mall · `video_shop` shop=video · `marketplace` amenity=marketplace |
| `poi_transport` | Transportation | `bus_stop` highway=bus_stop, or public_transport=stop_position + bus=yes · `bus_station` amenity=bus_station · `railway_station` railway=station · `railway_halt` railway=halt, or public_transport=stop_position + train=yes · `tram_stop` railway=tram_stop, or public_transport=stop_position + tram=yes · `ferry_terminal` amenity=ferry_terminal · `airport` amenity=airport, aeroway=aerodrome · `airfield` aeroway=airfield, military=airfield · `taxi` amenity=taxi · `post_office` amenity=post_office · `bicycle_rental` amenity=bicycle_rental · `car_sharing` amenity=car_sharing |
| `poi_essential` | Essential services | `bank` amenity=bank · `atm` amenity=atm · `pharmacy` amenity=pharmacy · `chemist` shop=chemist · `optician` shop=optician · `car_dealership` shop=car · `fuel` amenity=fuel · `hairdresser` shop=hairdresser · `beauty_shop` shop=beauty · `laundry` shop=laundry, shop=dry_cleaning · `car_repair` shop=car_repair · `car_wash` amenity=car_wash · `car_rental` amenity=car_rental · `travel_agent` shop=travel_agency · `veterinary` amenity=veterinary · `police` amenity=police · `fire_station` amenity=fire_station · `town_hall` amenity=townhall · `courthouse` amenity=courthouse · `embassy` amenity=embassy, office=diplomatic + diplomatic=embassy · `consulate` office=diplomatic + diplomatic=consulate · `wastewater_plant` man_made=wastewater_plant · `water_works` man_made=water_works |
| `poi_health` | **Health facilities** | `hospital` amenity=hospital · `clinic` amenity=clinic · `doctors` amenity=doctors · `dentist` amenity=dentist · `nursing_home` amenity=nursing_home |
| `poi_food` | Food and beverage | `restaurant` amenity=restaurant · `cafe` amenity=cafe · `bar` amenity=bar · `pub` amenity=pub · `fast_food` amenity=fast_food · `food_court` amenity=food_court · `biergarten` amenity=biergarten · `nightclub` amenity=nightclub |
| `poi_recreation` | Recreation and entertainment | `hotel` tourism=hotel · `motel` tourism=motel · `hostel` tourism=hostel · `guesthouse` tourism=guest_house · `chalet` tourism=chalet · `camp_site` tourism=camp_site · `caravan_site` tourism=caravan_site · `alpine_hut` tourism=alpine_hut · `cinema` amenity=cinema · `theatre` amenity=theatre · `arts_centre` amenity=arts_centre · `museum` tourism=museum · `zoo` tourism=zoo · `theme_park` tourism=theme_park · `attraction` tourism=attraction · `castle` historic=castle · `fort` historic=fort · `sports_centre` leisure=sports_centre · `fitness_centre` leisure=fitness_centre · `stadium` leisure=stadium · `sports_hall` leisure=sports_hall · `golf_course` leisure=golf_course · `ice_rink` leisure=ice_rink |
| `poi_education` | Education | `school` amenity=school · `kindergarten` amenity=kindergarten · `college` amenity=college · `university` amenity=university · `library` amenity=library |
| `poi_religious` | Religious and community | places of worship, all religions: amenity=place_of_worship + religion=* (`christian`, `christian_catholic`, `muslim`, `jewish`, `buddhist`, `hindu`, `sikh`, …) · `community_centre` amenity=community_centre |
| `poi_industrial` | Industrial and construction (land-use polygons) | `industrial` landuse=industrial · `quarry` landuse=quarry · `farmyard` landuse=farmyard · `construction` landuse=construction |
| `poi_buildings` | Residential and commercial buildings (building polygons) | building=apartments · building=commercial · building=office |
| `poi_other` | Other | remaining classes; in these extracts `graveyard` amenity=grave_yard, landuse=cemetery, and `prison` amenity=prison |
| `n_pharmacy` | Pharmacies (also in `poi_essential`) | `pharmacy` amenity=pharmacy |

Not counted:
- **Street furniture:** `bench`, `waste_basket`, `drinking_water`, `toilet`,
  `post_box`, `telephone`, `fountain`, `shelter`, `camera_surveillance`,
  `recycling*`, `vending*`
- **Landmarks:** `tourist_info`, `artwork`, `monument`, `memorial`, `ruins`,
  `archaeological`, `viewpoint`, `wayside_cross`, `wayside_shrine`,
  `battlefield`
- **Structures:** `tower`, `comms_tower`, `observation_tower`, `water_tower`,
  `lighthouse`, `windmill`, `water_mill`, `water_well`, `hunting_stand`
- **Open land and pools:** `park`, `playground`, `dog_park`, `pitch`,
  `track`, `picnic_site`, `swimming_pool` (mostly private pools)
- **Other:** `wilderness_hut`, `helipad`, `apron`

**Building density and land use** (`*_landuse`)

| Column | Content | Source |
|---|---|---|
| `built_share` | built-up surface / BHA surface, 0–1 | GHS-BUILT-S 2020 |
| `n_buildings`, `buildings_per_km2` | OSM buildings; per km² | OSM |
| `lu_residential` | share of the BHA (0-1) under landuse=residential | OSM |
| `lu_commercial` | … landuse=commercial, landuse=retail | OSM |
| `lu_industrial` | … landuse=industrial, landuse=quarry | OSM |
| `lu_agricultural` | … landuse=farmland, farmyard, orchard, vineyard, meadow, allotments | OSM |
| `lu_green` | … landuse=forest / natural=wood, landuse=scrub, landuse=grass, natural=heath, leisure=park / common, leisure=recreation_ground, leisure=nature_reserve | OSM |
