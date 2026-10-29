# OpenStreetMap points of interest and health facilities per BHA (Geofabrik extracts).

suppressPackageStartupMessages({library(sf); library(dplyr); library(tidyr)})

# POI categories as Geofabrik fclass values (OSM tags in SCHEMA.md)
POI_CLASSES = list(
	poi_industrial = c("landuse_industrial", "landuse_quarry", "landuse_farmyard",     # land-use polygons
		"landuse_construction"),
	poi_retail = c("supermarket", "convenience", "clothes", "bakery", "butcher", "greengrocer",
		"shoe_shop", "jeweller", "beverages", "bookshop", "gift_shop", "florist", "mobile_phone_shop",
		"bicycle_shop", "doityourself", "furniture_shop", "computer_shop", "sports_shop", "kiosk",
		"stationery", "toy_shop", "newsagent", "garden_centre", "outdoor_shop", "department_store",
		"general", "mall", "video_shop", "marketplace"),
	poi_transport = c("bus_stop", "bus_station", "railway_station", "railway_halt", "tram_stop",
		"ferry_terminal", "airport", "airfield", "taxi", "post_office", "bicycle_rental", "car_sharing"),
	poi_essential = c("bank", "atm", "pharmacy", "chemist", "optician", "car_dealership", "fuel",
		"hairdresser", "beauty_shop", "laundry", "car_repair", "car_wash", "car_rental",
		"travel_agent", "veterinary", "police", "fire_station", "town_hall", "courthouse",
		"consulate", "embassy", "wastewater_plant", "water_works"),
	poi_health = c("hospital", "clinic", "doctors", "dentist", "nursing_home"),
	poi_food = c("restaurant", "cafe", "bar", "pub", "fast_food", "food_court", "biergarten", "nightclub"),
	poi_recreation = c("hotel", "motel", "hostel", "guesthouse", "chalet", "camp_site", "caravan_site",
		"alpine_hut", "cinema", "theatre", "arts_centre", "museum", "zoo", "theme_park", "attraction",
		"castle", "fort", "sports_centre", "fitness_centre", "stadium", "sports_hall", "golf_course", "ice_rink"),
	poi_education = c("school", "kindergarten", "college", "university", "library"),
	poi_religious = c("place_of_worship", "community_centre"),
	poi_buildings = c("building_apartments", "building_commercial", "building_office")             # building polygons
)

# Not establishments: street furniture, landmarks, open land, private pools
POI_DROP = c("bench", "drinking_water", "waste_basket", "camera_surveillance", "artwork", "viewpoint",
	"toilet", "post_box", "telephone", "fountain", "shelter", "picnic_site", "wayside_cross",
	"wayside_shrine", "water_well", "comms_tower", "tower", "observation_tower", "water_tower",
	"lighthouse", "windmill", "water_mill", "hunting_stand", "track", "battlefield", "memorial",
	"monument", "ruins", "archaeological", "tourist_info", "wilderness_hut", "helipad", "apron",
	"swimming_pool", "pitch", "park", "playground", "dog_park")
POI_DROP_PREFIX = "^(recycling|vending)"   # recycling_glass, vending_parking, ...

osm_layer = function(name, layer, cols = "osm_id, fclass", where = NULL) {
	f = paste0("/vsizip/data/osm/", region(name)$osm, "/", layer, ".shp")
	read_sf(f, query = paste0("SELECT ", cols, " FROM ", layer, if (!is.null(where)) paste(" WHERE", where)))
}

# All candidate features as points in the BHAs' CRS
osm_features = function(name, bha) {
	pofw = \(l) osm_layer(name, l) |> mutate(fclass = "place_of_worship")
	pts = bind_rows(osm_layer(name, "gis_osm_pois_free_1"), pofw("gis_osm_pofw_free_1"),
			osm_layer(name, "gis_osm_transport_free_1"),
			osm_layer(name, "gis_osm_traffic_free_1", where = "fclass = 'fuel'")) |>
		st_transform(st_crs(bha))                                   # CRS: WGS84 -> BHAs' UTM
	pol = bind_rows(osm_layer(name, "gis_osm_pois_a_free_1"), pofw("gis_osm_pofw_a_free_1"),
			osm_layer(name, "gis_osm_transport_a_free_1"),
			osm_layer(name, "gis_osm_traffic_a_free_1", where = "fclass = 'fuel'"),
			osm_layer(name, "gis_osm_buildings_a_free_1", "osm_id, type AS fclass",
				"type IN ('apartments', 'commercial', 'office')") |> mutate(fclass = paste0("building_", fclass)),
			osm_layer(name, "gis_osm_landuse_a_free_1",
				where = "fclass IN ('industrial', 'quarry', 'farmyard', 'construction')") |> mutate(fclass = paste0("landuse_", fclass))) |>
		st_transform(st_crs(bha)) |>
		st_make_valid()
	# a facility mapped as both point and polygon counts once
	dup = mapply(\(i, f) any(pol$fclass[i] == f), st_within(pts, pol), pts$fclass)
	# polygons enter as one point each
	bind_rows(pts[!dup, ], st_set_agr(pol, "constant") |> st_point_on_surface())
}

# Classified points with the BHA each falls in
osm_points = function(name, bha = bha_geometry(name)) {
	category = setNames(rep(names(POI_CLASSES), lengths(POI_CLASSES)), unlist(POI_CLASSES))
	osm_features(name, bha) |>
		st_set_agr("constant") |>
		st_join(bha["id"], join = st_within) |>
		filter(!is.na(id)) |>                       # outside the region
		mutate(category = if_else(fclass %in% POI_DROP | grepl(POI_DROP_PREFIX, fclass), NA,
			coalesce(category[fclass], "poi_other")))
}

# Plain counts per BHA by category, plus pharmacies
osm_counts = function(name, bha = bha_geometry(name), pts = osm_points(name, bha)) {
	f = st_drop_geometry(pts)
	cols = c(names(POI_CLASSES), "poi_other")
	poi = f |> filter(!is.na(category)) |> count(id, category) |>
		pivot_wider(names_from = category, values_from = n, values_fill = 0)
	poi[setdiff(cols, names(poi))] = 0L
	tibble(id = bha$id) |>
		left_join(select(poi, id, all_of(cols)), by = "id") |>
		left_join(count(filter(f, fclass == "pharmacy"), id, name = "n_pharmacy"), by = "id") |>
		mutate(across(-id, \(v) as.integer(coalesce(v, 0))))
}

