# COVID-19 cases, mobility and covariates by basic health area: Catalunya and Madrid

Daily COVID-19 cases, mobility and covariates per BHA, 2020-03-01 →
2021-05-01. Basic health areas (BHAs) are the 374 ABS (àrees bàsiques de salut) of
Catalunya and the 286 ZBS (zonas básicas de salud) of the Comunidad de Madrid.

**Panel tables**, one row per BHA and day:
`outputs/catalunya/panel/cat_abs_main_noncollinear.parquet` and
`outputs/madrid/panel/mad_zbs_main_noncollinear.parquet`; as csv in the
[latest release](https://github.com/iprincegh/covid19-mobility-healthzones/releases/latest).
Columns and sources: [SCHEMA.md](SCHEMA.md).

**Mobility between BHAs** (daily MITMA trips, one parquet per month) is on
Zenodo: [doi:10.5281/zenodo.23737062](https://doi.org/10.5281/zenodo.23737062). See [Mobility](#mobility).

## Folder layout

```
covid19-mobility-healthzones/
├─ scripts/     the pipeline, run in order
├─ helpers/     functions used by the scripts
├─ reports/     figures and checks (Quarto)
├─ outputs/
│  ├─ catalunya/  and  madrid/, each with:
│  │  ├─ panel/    BHA × day tables: main and full
│  │  ├─ tables/   one csv per source, keyed, to combine freely
│  │  └─ geometry/ polygons, adjacency and distances
├─ mobility-data/ MITMA trips projected onto BHAs (Quarto)
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
bha = sf::read_sf("outputs/catalunya/geometry/cat_abs.gpkg")
```

Or read a table straight from GitHub, with no clone:

```r
cases = read.csv("https://raw.githubusercontent.com/iprincegh/covid19-mobility-healthzones/main/outputs/catalunya/tables/cat_abs_cases_daily.csv",
	colClasses = c(id = "character"))
```

The panel tables as csv are release assets (`cat_abs_main_noncollinear.csv`,
`cat_abs_full_allcovariates.csv`, `mad_zbs_main_noncollinear.csv`,
`mad_zbs_full_allcovariates.csv`), readable the same way:

```r
url = "https://github.com/iprincegh/covid19-mobility-healthzones/releases/download/v1.0/cat_abs_main_noncollinear.csv"
panel = read.csv(url, colClasses = c(id = "character"))
```

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
| `scripts/1_bha_cases_mobility.R` | BHAs, geometry, population, daily cases, mobility, vaccination (Catalunya) |
| `scripts/2_census_covariates.R` | census covariates per BHA |
| `scripts/3_osm_landuse.R` | points of interest, health facilities, building density, land use |
| `scripts/4_weather.R` | daily weather per BHA |
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

**`outputs/<region>/tables/`**: one csv per source. Join on the key.

| Table | Key | Content |
|---|---|---|
| `*_areas.csv` | `id` | BHA name, `area_km2` |
| `*_population.csv` | `id` | `pop` |
| `*_census_covariates.csv` | `id` | income, inequality, age, households, nationality, education, labour, housing, density |
| `*_census_covariates_point.csv` | `id` | the same, point-in-polygon assignment |
| `*_osm_pois.csv` | `id` | points of interest by category, health facilities, pharmacies |
| `*_landuse.csv` | `id` | building density, land-use shares |
| `*_cases_daily.csv` | `id` + `date` | new and cumulative cases |
| `*_mobility_daily.csv` | `id` + `date` | trips within, out of and into the BHA; MITMA population |
| `cat_abs_vaccination_daily.csv` | `id` + `date` | vaccination coverage |
| `*_weather_daily.csv` | `id` + `date` | temperature, precipitation, humidity (2020-01-01 → 2022-07-31) |
| `*_calendar_daily.csv` | `date` | day of week, public holiday |
| `*_restrictions_daily.csv` | `date` | state of alarm, work suspension, curfew |

**`outputs/<region>/geometry/`**: `*.gpkg` (polygons, key `id`) and
`*_topology.rds` (adjacency and distances in km between BHAs).

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
  preceding days, so counts stay non-negative and each BHA's total is
  unchanged.

## Mobility

MITMA trips are published between districts.
`mobility-data/Projecting_raw_mobility.qmd` projects them onto BHAs as in
Ponce-de-Leon et al. (2024): each district is split across BHAs by where its
residents live (GHS-POP 2020, 100 m), and a trip from district *i* to *l*
becomes trips from BHA *j* to *k* weighted by both shares. The result
(`source`, `target`, `trips` per day) is on Zenodo; `download/mobility_zenodo.R`
puts it in `data/`, so the 38 GB MITMA download is only needed to rebuild it.
Cite it as:

> Niraula, P., & Oppong Boakye, P. (2026). *Mobility data from MITMA, Spain reprojected at Zona Básica de Salud (ZBS) level for Madrid and Àrea Bàsica de Salut (ABS) for Catalunya* (Version 1.0) [Data set]. Zenodo. https://doi.org/10.5281/zenodo.23737062

## Census covariates: from sections to BHAs

Census covariates are published per census section (INE, about 1,000–2,500
residents). Each BHA holds several sections (median 13–15), so the
covariates are aggregated from small units to larger ones.

**Sections crossing a border.** Sections and BHAs were drawn
independently, so a few sections cross BHA borders. Such a section is split
between the BHAs by where its residents live (GHS-POP 2020, 100 m grid); a
section entirely inside one BHA goes to it whole.
`*_census_covariates_point.csv` uses a simpler rule: each section goes whole
to the BHA containing its point on surface.

**How values are combined.** Example: a BHA made of section A (1,000
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
| `flowmaps-data/` | COVID-19 cases and BHA geometry | BSC COVID-19 Flow-Maps, Zenodo 12207212 |
| `cat_od_bha_reprojected/`, `mad_od_bha_reprojected/` | MITMA trips between BHAs, one parquet per month | `mobility-data/Projecting_raw_mobility.qmd`; on Zenodo, fetched by `download/mobility_zenodo.R` |
| `spanish_od/` | MITMA origin–destination matrices (38 GB) | MITMA, `spanishoddata` |
| `health_data/` | official case series and health-zone boundaries | regional open-data portals |
| `covariates/raw/` | INE ADRH 2020, Census 2021, census sections 2020; AEMET and CatSalut data | INE, AEMET, CatSalut |
| `osm/` | OpenStreetMap extracts, Catalunya and Madrid | Geofabrik |
| `ghs_pop/`, `ghs_built/` | population and built-up surface grids, 100 m, 2020 | JRC GHSL |

## Weather

Daily temperature, precipitation and humidity from 105 AEMET stations. Each
BHA gets an inverse-distance-weighted mean of the 5 nearest stations within
75 km that reported that day. `dist_nearest_km` (full table) gives the distance
to the nearest station.

## Restrictions

Daily 0/1 indicators in `*_restrictions_daily.csv`, set from the decrees
(`helpers/restrictions.R`).

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
| Ponce-de-Leon, M. & Pontes, C. (2024), *From Movement to Infection: Deciphering COVID-19 Transmission via Transfer Entropy*, Zenodo, [doi:10.5281/zenodo.12207212](https://doi.org/10.5281/zenodo.12207212) (BSC COVID-19 Flow-Maps) | daily cases, BHA geometry, MITMA population | CC BY 4.0 |
| Ministerio de Transportes y Movilidad Sostenible (MITMA), open mobility data, via the `spanishoddata` R package | trips between BHAs | CC BY 4.0 |
| Niraula, P., & Oppong Boakye, P. (2026). *Mobility data from MITMA, Spain reprojected at Zona Básica de Salud (ZBS) level for Madrid and Àrea Bàsica de Salut (ABS) for Catalunya* (Version 1.0) [Data set]. Zenodo. [doi:10.5281/zenodo.23737062](https://doi.org/10.5281/zenodo.23737062) | trips between BHAs | CC BY 4.0 |
| Departament de Salut and CatSalut, Generalitat de Catalunya, [Dades obertes de Catalunya](https://analisi.transparenciacatalunya.cat) | official ABS cases (Montcada), registered population, vaccination | open data licence of the Generalitat, attribution |
| Comunidad de Madrid, [datos abiertos](https://datos.comunidad.madrid) | ZBS boundaries and population | CC BY 4.0 |
| Instituto Nacional de Estadística ([INE](https://www.ine.es)): ADRH 2020, census sections 2020, Census 2021 | census covariates | reuse with attribution ("Fuente: INE") |
| Institut d'Estadística de Catalunya ([Idescat](https://www.idescat.cat)) | census covariates, Catalunya | CC BY 4.0 |
| Agencia Estatal de Meteorología ([AEMET OpenData](https://opendata.aemet.es)) | daily weather | reuse with attribution ("© AEMET") |
| © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors, extracts by Geofabrik | points of interest, health facilities, land use | ODbL 1.0 |
| European Commission, JRC, [GHSL](https://human-settlement.emergency.copernicus.eu): GHS-POP and GHS-BUILT-S 2020 (R2023A) | population weights, built-up share | CC BY 4.0 |
| BOE, DOGC and BOCM (decrees in [Restrictions](#restrictions)) | restriction dates | public legal texts |

