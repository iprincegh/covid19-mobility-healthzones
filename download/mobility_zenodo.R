# MITMA trips between BHAs (monthly parquet) from Zenodo, doi:10.5281/zenodo.23737062,
# into data/cat_od_bha_reprojected/ and data/mad_od_bha_reprojected/.
# Built by mobility-data/Projecting_raw_mobility.qmd.

url = "https://zenodo.org/records/23737062/files/%s-%s.parquet?download=1"
dirs = c(Catalunya = "data/cat_od_bha_reprojected", Madrid = "data/mad_od_bha_reprojected")
months = format(seq(as.Date("2020-02-01"), as.Date("2021-05-01"), by = "month"), "%Y-%m")
options(timeout = 1800)

for (r in names(dirs)) {
	dir.create(dirs[[r]], recursive = TRUE, showWarnings = FALSE)
	for (m in months) {
		f = file.path(dirs[[r]], paste0(m, ".parquet"))
		if (file.exists(f)) next
		download.file(sprintf(url, r, m), f, quiet = TRUE, mode = "wb")
		message("downloaded ", r, " ", m)
	}
}
