# GHS-BUILT-S 2020 (JRC) built-up surface tiles over Spain into data/ghs_built/.

url = "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_BUILT_S_GLOBE_R2023A/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_100/V1-0/tiles/GHS_BUILT_S_E2020_GLOBE_R2023A_54009_100_V1_0_%s.zip"
dir = "data/ghs_built"
dir.create(dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 1800)

for (t in c("R4_C19", "R5_C18", "R5_C19")) {
	if (length(list.files(dir, paste0(t, "\\.tif$")))) next
	zip = tempfile(fileext = ".zip")
	download.file(sprintf(url, t), zip, quiet = TRUE, mode = "wb")
	unzip(zip, exdir = dir, files = grep("\\.tif$", unzip(zip, list = TRUE)$Name, value = TRUE))
	message("downloaded ", t)
}
