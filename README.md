# COVID-19 cases, mobility and covariates by health area: Catalunya and Madrid

Daily COVID-19 cases, mobility and covariates per health area, 2020-03-01 →
2021-05-01. Health areas are the 374 ABS (àrees bàsiques de salut) of Catalunya
and the 286 ZBS (zonas básicas de salud) of the Comunidad de Madrid.

**Panel tables**, one row per health area and day:
`outputs/catalunya/panel/cat_abs_main_noncollinear.parquet` and
`outputs/madrid/panel/mad_zbs_main_noncollinear.parquet`. The same tables as
csv are attached to the [latest release](https://github.com/iprincegh/covid19-mobility-healthzones/releases/latest).
Columns and sources: [SCHEMA.md](SCHEMA.md).

## Folder layout

```
covid19-mobility-healthzones/
├─ scripts/     the pipeline, run in order
├─ helpers/     functions used by the scripts
├─ reports/     figures and checks (Quarto)
├─ outputs/
│  ├─ catalunya/  and  madrid/, each with:
│  │  ├─ panel/    health area × day tables: main and full
│  │  ├─ tables/   one csv per source, keyed, to combine freely
│  │  └─ geometry/ polygons, adjacency and distances
├─ download/    scripts that fetch the raw inputs
└─ data/        raw inputs (not in the repository)
```

## Using the tables

Every path in the code is relative to the repository folder. Clone it and set
the working directory there once, with its absolute path:

```r
setwd("~/covid19-mobility-healthzones")   # where you cloned it
cases = read.csv("outputs/catalunya/tables/cat_abs_cases_daily.csv", colClasses = c(id = "character"))
panel = arrow::read_parquet("outputs/catalunya/panel/cat_abs_main_noncollinear.parquet")
areas = sf::read_sf("outputs/catalunya/geometry/cat_abs.gpkg")
```

Or read a table straight from GitHub, with no clone:

```r
cases = read.csv("https://raw.githubusercontent.com/iprincegh/covid19-mobility-healthzones/main/outputs/catalunya/tables/cat_abs_cases_daily.csv",
	colClasses = c(id = "character"))
```

The panel tables as csv are release assets. To read one in R without
downloading it by hand:

```r
url = "https://github.com/iprincegh/covid19-mobility-healthzones/releases/download/v1.0/cat_abs_main_noncollinear.csv"
panel = read.csv(url, colClasses = c(id = "character"))
```

The other assets are `cat_abs_full_allcovariates.csv`,
`mad_zbs_main_noncollinear.csv` and `mad_zbs_full_allcovariates.csv`.

Keep `colClasses = c(id = "character")` so `id` keeps its leading zeros.

## How to rebuild

Rebuilding needs the raw inputs in `data/` (see [Input data](#input-data-data)).
The scripts in `download/` fetch most of them. `download/aemet.R` needs your own
free AEMET OpenData API key (opendata.aemet.es), set for the session only:
`Sys.setenv(AEMET_API_KEY = "...")`.

With the working directory set to the repository folder, run
`source("scripts/run_all.R")`, or the steps one by one:

| Script | Builds |
|---|---|
| `scripts/1_areas_cases_mobility.R` | health areas, geometry, population, daily cases, mobility, vaccination (Catalunya) |
| `scripts/2_census_covariates.R` | census covariates per health area |
| `scripts/3_osm_landuse.R` | points of interest, health facilities, building density, land use |
| `scripts/4_weather.R` | daily weather per health area |
| `scripts/5_panel_tables.R` | calendar, restrictions and the panel tables (main, full) |

R packages: sf, dplyr, tidyr, data.table, arrow, terra, exactextractr, spdep;
for the reports also ggplot2, patchwork, classInt, RColorBrewer, mgcv.
Render a report with `quarto render reports/figures.qmd` from the repository folder.

## Outputs

**`outputs/<region>/panel/`**

| File | Content |
|---|---|
| `*_main_noncollinear.parquet` | main table: 34 columns, covariates with low collinearity |
| `*_full_allcovariates.parquet` | full table: every covariate (56 Catalunya, 55 Madrid) |

`<region>` is `catalunya` or `madrid`; file names start with `cat_abs` or `mad_zbs`.
The csv versions are in the [release](https://github.com/iprincegh/covid19-mobility-healthzones/releases/latest).

**`outputs/<region>/tables/`**: one csv per source. Join on the key.

| Table | Key | Content |
|---|---|---|
| `*_areas.csv` | `id` | health area name, `area_km2` |
| `*_population.csv` | `id` | `pop` |
| `*_census_covariates.csv` | `id` | income, inequality, age, households, nationality, education, labour, housing, density |
| `*_census_covariates_point.csv` | `id` | the same, point-in-polygon assignment |
| `*_osm_pois.csv` | `id` | points of interest by category, health facilities, pharmacies |
| `*_landuse.csv` | `id` | building density, land-use shares |
| `*_cases_daily.csv` | `id` + `date` | new and cumulative cases |
| `*_mobility_daily.csv` | `id` + `date` | trips within, out of and into the health area; MITMA population |
| `cat_abs_vaccination_daily.csv` | `id` + `date` | vaccination coverage |
| `*_weather_daily.csv` | `id` + `date` | temperature, precipitation, humidity (2020-01-01 → 2022-07-31) |
| `*_calendar_daily.csv` | `date` | day of week, public holiday |
| `*_restrictions_daily.csv` | `date` | state of alarm, work suspension, curfew |

Read csv files with `colClasses = c(id = "character")` to keep the leading
zeros of `id`.

**`outputs/<region>/geometry/`**: `*.gpkg` (polygons, key `id`) and
`*_topology.rds` (adjacency and distances in km between health areas).

## Cases

Daily cases come from Flow-Maps, with two corrections:

- **Montcada i Reixac (Catalunya).** The official data report it as one ABS
  (302); Flow-Maps splits it into 381 and 382. Flow-Maps gives 382 the whole
  official series and 381 the same series plus about 12,000 cases with no ABS
  recorded. Both get the official ABS 302 series
  (`data/health_data/catalunya/data/covid19_abs_catalunya.csv`) instead,
  split by MITMA population (381: 41%, 382: 59%). Together they add up to 302
  exactly: 3,328 cases in the window.
- **Negative daily counts (Madrid).** Downward revisions are removed from the
  preceding days, so counts stay non-negative and each health area's total is
  unchanged.

## Census covariates: from sections to health areas

Census covariates are published per census section (INE, about 1,000–2,500
residents). Each health area holds several sections (median 13–15), so the
covariates are aggregated from small units to larger ones.

**Sections crossing a border.** Sections and health areas were drawn
independently, so a few sections cross health area borders. Such a section is split
between the health areas by where its residents live (GHS-POP 2020, 100 m grid); a
section entirely inside one health area goes to it whole.
`*_census_covariates_point.csv` uses a simpler rule: each section goes whole
to the health area containing its point on surface.

**How values are combined.** Example: a health area made of section A (1,000
residents, 300 aged 65+, median income €15,000) and section B (3,000 residents,
300 aged 65+, median income €25,000).

| Kind | Rule | Example |
|---|---|---|
| Counts (residents, households, dwellings) | summed | 1,000 + 3,000 = 4,000 residents |
| Shares (% aged 65+, % foreign, …) | rebuilt from counts: numerators summed over denominators summed (exact) | (300 + 300) / 4,000 = 15% |
| Median income, Gini | population-weighted mean of section values (an approximation; the exact value needs household data) | (1,000 × 15,000 + 3,000 × 25,000) / 4,000 = €22,500 |

## Input data (`data/`)

| Folder | What it is | Source |
|---|---|---|
| `flowmaps-data/` | COVID-19 cases and health area geometry | BSC COVID-19 Flow-Maps, Zenodo 12207212 |
| `cat_od_bha_reprojected/`, `mad_od_bha_reprojected/` | MITMA trips between health areas, one parquet per month | derived from `spanish_od/` |
| `spanish_od/` | MITMA origin–destination matrices (38 GB) | MITMA, `spanishoddata` |
| `health_data/` | official case series and health-zone boundaries | regional open-data portals |
| `covariates/raw/` | INE ADRH 2020, Census 2021, census sections 2020; AEMET and CatSalut data | INE, AEMET, CatSalut |
| `osm/` | OpenStreetMap extracts, Catalunya and Madrid | Geofabrik |
| `ghs_pop/`, `ghs_built/` | population and built-up surface grids, 100 m, 2020 | JRC GHSL |

## Weather

Daily temperature, precipitation and humidity from 105 AEMET stations. Each
health area gets an inverse-distance-weighted mean of the 5 nearest stations within
75 km that reported that day. `dist_nearest_km` (full table) gives the distance
to the nearest station.

## Restrictions

Daily 0/1 indicators in `*_restrictions_daily.csv`, set from the decrees
(`helpers/restrictions.R`). The figures use the same names.

| Measure | Column | Region | Dates in force | Source |
|---|---|---|---|---|
| First state of alarm | `npi_alarm` | Spain | 2020-03-14 → 2020-06-20 | [Real Decreto 463/2020](https://www.boe.es/eli/es/rd/2020/03/14/463), BOE 14-03-2020, and its extensions |
| Second state of alarm | `npi_alarm` | Spain | 2020-10-25 → 2021-05-09 | [Real Decreto 926/2020](https://www.boe.es/eli/es/rd/2020/10/25/926), BOE 25-10-2020; extended by [Real Decreto 956/2020](https://www.boe.es/eli/es/rd/2020/11/03/956) |
| Non-essential work suspended | `npi_hibernation` | Spain | 2020-03-30 → 2020-04-09 | [Real Decreto-ley 10/2020](https://www.boe.es/eli/es/rdl/2020/03/29/10), BOE 29-03-2020 |
| Curfew, 22:00–06:00 | `npi_curfew` | Catalunya | 2020-10-25 → 2021-05-09 | [Resolució SLT/2620/2020](https://dogc.gencat.cat/es/pdogc_canals_interns/pdogc_resultats_fitxa/index.html?action=fitxa&documentId=884771&language=ca_ES&newLang=es_ES), DOGC 8254, 25-10-2020 |
| Curfew, from 00:00 | `npi_curfew` | Madrid | 2020-10-25 → 2021-05-09 | [Decreto 29/2020](https://www.bocm.es/boletin/CM_Orden_BOCM/2020/10/26/BOCM-20201026-206.PDF), BOCM 261, 26-10-2020; 23:00 from 2021-01-18 (Decreto 3/2021); 22:00 from 2021-01-25 ([Decreto 4/2021](https://www.bocm.es/boletin/CM_Orden_BOCM/2021/01/23/BOCM-20210123-1.PDF), BOCM 19, 23-01-2021) |

The first state of alarm ended at 00:00 on 2020-06-21, so 2020-06-20 is its
last day. Both curfews start with the second state of alarm, which set a
national curfew from 2020-10-25. Measures past 2021-05-01 run beyond the panel
window.

## Coordinate reference systems

Outputs use each region's UTM zone: EPSG:25831 (Catalunya), EPSG:25830 (Madrid).

## Attribution

The outputs are derived from the sources below. Reuse them under the same terms
and credit the sources.

| Source | Used for | Licence / terms |
|---|---|---|
| Ponce-de-Leon, M. & Pontes, C. (2024), *From Movement to Infection: Deciphering COVID-19 Transmission via Transfer Entropy*, Zenodo, [doi:10.5281/zenodo.12207212](https://doi.org/10.5281/zenodo.12207212) (BSC COVID-19 Flow-Maps) | daily cases, health area geometry, MITMA population | CC BY 4.0 |
| Ministerio de Transportes y Movilidad Sostenible (MITMA), open mobility data, via the `spanishoddata` R package | trips between health areas | CC BY 4.0 |
| Departament de Salut and CatSalut, Generalitat de Catalunya, [Dades obertes de Catalunya](https://analisi.transparenciacatalunya.cat) | official ABS cases (Montcada), registered population, vaccination | open data licence of the Generalitat, attribution |
| Comunidad de Madrid, [datos abiertos](https://datos.comunidad.madrid) | ZBS boundaries and population | CC BY 4.0 |
| Instituto Nacional de Estadística ([INE](https://www.ine.es)): ADRH 2020, census sections 2020, Census 2021 | census covariates | reuse with attribution ("Fuente: INE") |
| Institut d'Estadística de Catalunya ([Idescat](https://www.idescat.cat)) | census covariates, Catalunya | CC BY 4.0 |
| Agencia Estatal de Meteorología ([AEMET OpenData](https://opendata.aemet.es)) | daily weather | reuse with attribution ("© AEMET") |
| © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors, extracts by Geofabrik | points of interest, health facilities, land use | ODbL 1.0 |
| European Commission, JRC, [GHSL](https://human-settlement.emergency.copernicus.eu): GHS-POP and GHS-BUILT-S 2020 (R2023A) | population weights, built-up share | CC BY 4.0 |
| BOE, DOGC and BOCM (decrees in [Restrictions](#restrictions)) | restriction dates | public legal texts |

