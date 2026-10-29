# COVID-19 cases, mobility and covariates by basic health area: Catalunya and Madrid

Daily COVID-19 cases, mobility and covariates per basic health area (BHA),
2020-03-01 → 2021-05-01. The BHAs are the 374 ABS (àrees bàsiques de salut) of
Catalunya and the 286 ZBS (zonas básicas de salud) of the Comunidad de Madrid.

- **Panel tables**, one row per BHA and day: `outputs/<region>/panel/`;
  as csv in the [latest release](https://github.com/iprincegh/covid19-mobility-healthzones/releases/latest). Columns: [SCHEMA.md](SCHEMA.md).
- **Mobility between BHAs**, daily MITMA trips: on Zenodo,
  [doi:10.5281/zenodo.23737062](https://doi.org/10.5281/zenodo.23737062) (see [Mobility](#mobility)).

## Folder layout

```
covid19-mobility-healthzones/
├─ scripts/        pipeline, run in order
├─ helpers/        functions used by the scripts
├─ reports/        figures and checks (Quarto)
├─ mobility-data/  projection of MITMA trips onto BHAs (Quarto)
├─ download/       scripts that fetch the raw inputs
├─ outputs/
│  └─ catalunya/, madrid/
│     ├─ panel/    BHA × day tables: main and full
│     ├─ tables/   one csv per source
│     └─ geometry/ polygons, adjacency, distances
└─ data/           raw inputs (not in the repository)
```

## Reading the tables

Paths are relative to the repository folder. Set it as the working directory:

```r
setwd("~/covid19-mobility-healthzones")
cases = read.csv("outputs/catalunya/tables/cat_abs_cases_daily.csv", colClasses = c(id = "character"))
panel = arrow::read_parquet("outputs/catalunya/panel/cat_abs_main_noncollinear.parquet")
bha = sf::read_sf("outputs/catalunya/geometry/cat_abs.gpkg")
```

Without cloning, read a table from GitHub, or a panel csv from the release
(`cat_abs_main_noncollinear.csv`, `cat_abs_full_allcovariates.csv`,
`mad_zbs_main_noncollinear.csv`, `mad_zbs_full_allcovariates.csv`):

```r
cases = read.csv("https://raw.githubusercontent.com/iprincegh/covid19-mobility-healthzones/main/outputs/catalunya/tables/cat_abs_cases_daily.csv",
	colClasses = c(id = "character"))
panel = read.csv("https://github.com/iprincegh/covid19-mobility-healthzones/releases/download/v1.0/cat_abs_main_noncollinear.csv",
	colClasses = c(id = "character"))
```

`colClasses = c(id = "character")` keeps the leading zeros of `id`.

## Rebuilding

The pipeline reads the raw inputs in `data/` ([Input data](#input-data)); the
scripts in `download/` fetch most of them. `download/aemet.R` needs your own
AEMET OpenData API key (opendata.aemet.es): `Sys.setenv(AEMET_API_KEY = "...")`.

From the repository folder, run `source("scripts/run_all.R")`, or the steps in order:

| Script | Builds |
|---|---|
| `scripts/1_bha_cases_mobility.R` | BHAs, geometry, population, cases, mobility, vaccination (Catalunya) |
| `scripts/2_census_covariates.R` | census covariates |
| `scripts/3_osm_landuse.R` | points of interest, health facilities, building density, land use |
| `scripts/4_weather.R` | weather |
| `scripts/5_panel_tables.R` | calendar, restrictions, panel tables |

R packages: sf, dplyr, tidyr, data.table, arrow, terra, exactextractr, spdep;
for the reports also ggplot2, patchwork, classInt, RColorBrewer, mgcv. Render a
report with `quarto render reports/figures.qmd`.

## Outputs

`<region>` is `catalunya` (files `cat_abs_*`) or `madrid` (files `mad_zbs_*`).

**`outputs/<region>/panel/`**

| File | Content |
|---|---|
| `*_main_noncollinear.parquet` | 34 columns; covariates with low collinearity |
| `*_full_allcovariates.parquet` | all covariates: 56 columns (Catalunya), 55 (Madrid) |

**`outputs/<region>/tables/`**: one csv per source, joined on the key.

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
`*_topology.rds` (adjacency matrix, distances in km).

Coordinates are in each region's UTM zone: EPSG:25831 (Catalunya), EPSG:25830 (Madrid).

## Cases

Cases come from Flow-Maps, with two corrections:

- **Montcada i Reixac (Catalunya).** The official data have one ABS (302);
  Flow-Maps has two (381, 382). Flow-Maps gives 382 the official series and 381
  the same series plus about 12,000 cases with no ABS recorded. Both get the
  official ABS 302 series instead, split by MITMA population (381: 41%,
  382: 59%), 3,328 cases in total.
- **Negative daily counts (Madrid).** Each downward revision is subtracted from
  the preceding days. Counts stay non-negative and each BHA's total is unchanged.

## Mobility

MITMA publishes trips between districts. `mobility-data/Projecting_raw_mobility.qmd`
projects them onto BHAs as in Ponce-de-Leon et al. (2024): each district is split
across BHAs by population (GHS-POP 2020, 100 m), and a trip from district *i* to
*l* becomes trips from BHA *j* to *k*, weighted by both shares. The result
(`date`, `source`, `target`, `trips`) is on Zenodo; `download/mobility_zenodo.R`
copies it to `data/`. The 38 GB MITMA download is needed only to rebuild it.

> Niraula, P., & Oppong Boakye, P. (2026). *Mobility data from MITMA, Spain reprojected at Zona Básica de Salud (ZBS) level for Madrid and Àrea Bàsica de Salut (ABS) for Catalunya* (Version 1.0) [Data set]. Zenodo. https://doi.org/10.5281/zenodo.23737062

## Census covariates: from sections to BHAs

INE publishes census covariates per census section (about 1,000–2,500
residents). A BHA contains a median of 13–15 sections.

A section that crosses a BHA border is split by where its residents live
(GHS-POP 2020, 100 m). `*_census_covariates_point.csv` instead assigns each
section whole to the BHA that contains its point on surface.

Example: a BHA made of section A (1,000 residents, 300 aged 65+, median income
€15,000) and section B (3,000 residents, 300 aged 65+, median income €25,000).

| Kind | Rule | Example |
|---|---|---|
| Counts (residents, households, dwellings) | sum | 1,000 + 3,000 = 4,000 residents |
| Shares (% aged 65+, % foreign, …) | sum of numerators / sum of denominators | (300 + 300) / 4,000 = 15% |
| Median income, Gini | population-weighted mean (approximation; the exact value needs household data) | (1,000 × 15,000 + 3,000 × 25,000) / 4,000 = €22,500 |

## Weather

Daily temperature, precipitation and humidity from 105 AEMET stations. Each BHA
gets the inverse-distance-weighted mean of the 5 nearest stations within 75 km
that reported that day. `dist_nearest_km` (full table) is the distance to the
nearest station.

## Restrictions

Daily 0/1 indicators in `*_restrictions_daily.csv`, defined in `helpers/restrictions.R`.

| Measure | Column | Region | Dates in force | Source |
|---|---|---|---|---|
| First state of alarm | `npi_alarm` | Spain | 2020-03-14 → 2020-06-20 | [Real Decreto 463/2020](https://www.boe.es/eli/es/rd/2020/03/14/463), BOE 14-03-2020, and its extensions |
| Second state of alarm | `npi_alarm` | Spain | 2020-10-25 → 2021-05-09 | [Real Decreto 926/2020](https://www.boe.es/eli/es/rd/2020/10/25/926), BOE 25-10-2020; extended by [Real Decreto 956/2020](https://www.boe.es/eli/es/rd/2020/11/03/956) |
| Non-essential work suspended | `npi_hibernation` | Spain | 2020-03-30 → 2020-04-09 | [Real Decreto-ley 10/2020](https://www.boe.es/eli/es/rdl/2020/03/29/10), BOE 29-03-2020 |
| Curfew, 22:00–06:00 | `npi_curfew` | Catalunya | 2020-10-25 → 2021-05-09 | [Resolució SLT/2620/2020](https://dogc.gencat.cat/es/pdogc_canals_interns/pdogc_resultats_fitxa/index.html?action=fitxa&documentId=884771&language=ca_ES&newLang=es_ES), DOGC 8254, 25-10-2020 |
| Curfew, from 00:00 | `npi_curfew` | Madrid | 2020-10-25 → 2021-05-09 | [Decreto 29/2020](https://www.bocm.es/boletin/CM_Orden_BOCM/2020/10/26/BOCM-20201026-206.PDF), BOCM 261, 26-10-2020; 23:00 from 2021-01-18 (Decreto 3/2021); 22:00 from 2021-01-25 ([Decreto 4/2021](https://www.bocm.es/boletin/CM_Orden_BOCM/2021/01/23/BOCM-20210123-1.PDF), BOCM 19, 23-01-2021) |

The first state of alarm ended at 00:00 on 2020-06-21. Both curfews began with
the second state of alarm. Measures ending after 2021-05-01 are cut at the end
of the panel.

## Input data

`data/` is not in the repository.

| Folder | What it is | Source |
|---|---|---|
| `flowmaps-data/` | COVID-19 cases and BHA geometry | BSC COVID-19 Flow-Maps, Zenodo 12207212 |
| `cat_od_bha_reprojected/`, `mad_od_bha_reprojected/` | MITMA trips between BHAs, one parquet per month | `mobility-data/Projecting_raw_mobility.qmd`; on Zenodo, fetched by `download/mobility_zenodo.R` |
| `spanish_od/` | MITMA origin–destination matrices (38 GB) | MITMA, `spanishoddata` |
| `health_data/` | official case series and health-zone boundaries | regional open-data portals |
| `covariates/raw/` | INE ADRH 2020, Census 2021, census sections 2020; AEMET and CatSalut data | INE, AEMET, CatSalut |
| `osm/` | OpenStreetMap extracts, Catalunya and Madrid | Geofabrik |
| `ghs_pop/`, `ghs_built/` | population and built-up surface grids, 100 m, 2020 | JRC GHSL |

## Attribution

Credit these sources when reusing the outputs, under their terms.

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
