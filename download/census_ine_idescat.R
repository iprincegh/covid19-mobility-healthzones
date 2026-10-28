# INE ADRH 2020, INE census-section boundaries 2020 and Idescat IST 2021 into
# data/covariates/raw/. Existing files are skipped.

options(timeout = 1800)

RAW      <- file.path("data", "covariates", "raw")  # relative to the repository folder
DIR_ADRH <- file.path(RAW, "adrh_2020")
DIR_SECT <- file.path(RAW, "ine_sections_2020")
DIR_IST  <- file.path(RAW, "idescat_ist_2021")
for (d in c(DIR_ADRH, DIR_SECT, DIR_IST)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

TODAY <- format(Sys.Date(), "%Y-%m-%d")
manifest <- list()

add_manifest <- function(dataset, file_name, source_url, reference_year,
                         geography_level, provinces_covered, notes = "") {
  manifest[[length(manifest) + 1]] <<- data.frame(
    dataset = dataset, file_name = file_name, source_url = source_url,
    date_accessed = TODAY, reference_year = reference_year,
    geography_level = geography_level, provinces_covered = provinces_covered,
    notes = notes, stringsAsFactors = FALSE)
}

fetch <- function(url, dest, binary = TRUE) {
  if (file.exists(dest) && file.size(dest) > 0) {
    message("   skip (exists): ", basename(dest)); return(TRUE)
  }
  ok <- tryCatch({
    download.file(url, dest, mode = if (binary) "wb" else "w", quiet = TRUE)
    TRUE
  }, error = function(e) { message("   FAILED: ", basename(dest), " -> ",
                                   conditionMessage(e)); FALSE })
  if (ok) message(sprintf("   ok: %-52s %8.1f KB", basename(dest), file.size(dest)/1024))
  ok
}

# ============================================================ 1. ADRH 2020 ====
# Province -> block of 9 consecutive table ids (base .. base+8) covering:
#   base+0 renta media y mediana      base+1 distribución por fuente de ingresos
#   base+2..4 % bajo umbrales (3)     base+5..7 % bajo/encima umbrales (3)
#   base+8 indicadores demográficos
# The Gini / P80-P20 table sits in a separate id range, hence a second column.
adrh_blocks <- data.frame(
  prov  = c("08", "17", "25", "28", "43"),
  name  = c("Barcelona", "Girona", "Lleida", "Madrid", "Tarragona"),
  base  = c(30896, 31016, 31079, 31097, 31223),
  gini  = c(37686, 37697, 37704, 37727, 37718),
  stringsAsFactors = FALSE)

adrh_labels <- c("renta_media_mediana", "distribucion_fuente_ingresos",
                 "pct_bajo_umbrales_sexo", "pct_bajo_umbrales_sexo_edad",
                 "pct_bajo_umbrales_sexo_nacionalidad",
                 "pct_bajo_encima_umbrales_sexo",
                 "pct_bajo_encima_umbrales_sexo_edad",
                 "pct_bajo_encima_umbrales_sexo_nacionalidad",
                 "indicadores_demograficos")

message("== 1. INE ADRH (census-section level) ==")
for (i in seq_len(nrow(adrh_blocks))) {
  p <- adrh_blocks$prov[i]; nm <- adrh_blocks$name[i]
  ids    <- c(adrh_blocks$base[i] + 0:8, adrh_blocks$gini[i])
  labels <- c(adrh_labels, "indice_gini_p80p20")
  message(" -- province ", p, " ", nm)
  for (j in seq_along(ids)) {
    url  <- sprintf("https://www.ine.es/jaxiT3/files/t/es/csv_bdsc/%d.csv", ids[j])
    fn   <- sprintf("adrh_%s_%s_t%d.csv", p, labels[j], ids[j])
    if (fetch(url, file.path(DIR_ADRH, fn))) {
      add_manifest("INE ADRH", fn, url, "2020 (file contains 2015-2023)",
                   "seccion censal / distrito / municipio", p,
                   sprintf("province %s %s; INE table id %d; semicolon CSV, ISO-8859-15", p, nm, ids[j]))
    }
  }
}

# ================================================= 2. INE section boundaries ==
message("\n== 2. INE census-section cartography 2020 ==")
carto_url <- "https://www.ine.es/prodyser/cartografia/seccionado_2020.zip"
carto_dst <- file.path(DIR_SECT, "seccionado_2020.zip")
if (fetch(carto_url, carto_dst)) {
  add_manifest("INE cartografia secciones censales", basename(carto_dst), carto_url,
               "2020", "seccion censal", "national (all 52 provinces)",
               "shapefile zip, as published; not unpacked by this script")
}

# ============================================================ 3. IDESCAT IST ==
# Section-level IST via the API, split by year and concept (the API caps rows)
ist_jobs <- rbind(
  data.frame(tbl = "14034", node = "14994", concept = NA_character_,
             label = "ist_index", stringsAsFactors = FALSE),
  data.frame(tbl = "14036", node = "14992",
             concept = c("POP_PS_EDU", "POP_Y_WSTU", "POP_INC_LM", "AVER_INC"),
             label = paste0("indicadors_estandarditzats_",
                            c("POP_PS_EDU", "POP_Y_WSTU", "POP_INC_LM", "AVER_INC")),
             stringsAsFactors = FALSE),
  data.frame(tbl = "14074", node = "15022",
             concept = c("POP_PS_EDU_PERC", "POP_Y_WSTU_PERC", "POP_INC_LM_PERC", "AVER_INC_EUR"),
             label = paste0("indicadors_valors_",
                            c("POP_PS_EDU_PERC", "POP_Y_WSTU_PERC", "POP_INC_LM_PERC", "AVER_INC_EUR")),
             stringsAsFactors = FALSE))

message("\n== 3. IDESCAT IST 2021 (census-section level) ==")
for (i in seq_len(nrow(ist_jobs))) {
  u <- sprintf("https://api.idescat.cat/taules/v2/ist/%s/%s/sec/data?YEAR=2021&format=json",
               ist_jobs$tbl[i], ist_jobs$node[i])
  if (!is.na(ist_jobs$concept[i])) u <- paste0(u, "&CONCEPT=", ist_jobs$concept[i])
  fn <- sprintf("idescat_ist_2021_sec_%s.json", ist_jobs$label[i])
  if (fetch(u, file.path(DIR_IST, fn))) {
    add_manifest("IDESCAT IST", fn, u, "2021", "seccio censal",
                 "Catalunya (08, 17, 25, 43)",
                 paste0("JSON-stat; API returns JSON even when format=csv is requested",
                        if (!is.na(ist_jobs$concept[i]))
                          paste0("; CONCEPT=", ist_jobs$concept[i]) else ""))
  }
}


# ================================================================ MANIFEST ====
man <- do.call(rbind, manifest)
write.csv(man, file.path(RAW, "MANIFEST.csv"), row.names = FALSE, fileEncoding = "UTF-8")
message("\nMANIFEST.csv written: ", nrow(man), " rows")
message("Done.")
