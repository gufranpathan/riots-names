# Riot names

Estimates the effect of Hindu–Muslim riots on how religiously distinctive children's names are. The outcome is the religious name index (RNI) of each birth cohort, by district, from electoral rolls. Riots are instrumented with Hindu festivals that fall on a Friday (Iyer and Shrivastava 2018; Goyal and van Noort 2025).

There are two versions of the RNI. The frozen RNI (`data/0_raw/segregation data 2026/`) scores every name on voters born before 1970 and covers births 1971–1997; it is the main outcome. The older `rni_annual` files cover births from 1950 and feed the original specification (riot years 1950–1994).

## Layout

- `_targets.R`: the pipeline. Each target `x` is built by a function `get_x()` in `R/`; file targets `x_path` are built by `get_x()`. The Iyer-style targets are built once per RNI version with `tarchetypes::tar_map()` and carry the suffix `_frozen` or `_annual` (for example `rni_riots_iyer_frozen`).
- `R/00_utils.R`: `save_track_object()` and `save_track_plot()`, which write outputs and record their paths.
- `R/01_*.R`: reading and cleaning. `01_rni_read.R` (both RNI versions), `01_riots_cleaning.R` (Goyal riots), `01_festival.R` (Iyer's festival instrument), `01_spatial.R` (constituency map, district centroids, spatial riot kernel).
- `R/02_*.R`: models. `02_models.R` is the original specification; `02_iyer_data.R`, `02_iyer_models.R` and `02_iyer_benchmarks.R` are the Iyer-style specification (riot years 1970–1995).
- `R/03_*.R`, `R/04_*.R`: descriptive tables and plots for the original specification. `R/99_*.R` are scratch scripts outside the pipeline.
- `data/0_raw/`: raw inputs, not in git; a copy of the CEGA Dropbox folder `Riot Names Data/data/0_raw`. Riots: `01-riots/` (Goyal and van Noort and Iyer and Shrivastava replication files, Varshney–Wilkinson data). RNI: `segregation data 2026/` (frozen, one booth-level CSV) and `rni_annual/ac_year/` (one file per state). Constituency-to-district mapping: `12-delim4/`. Constituency map: `13-ac-shapefile/` (DataMeet, CC BY 2.5 IN).
- `data/02_output/`: tables (LaTeX rows and CSV files) and plots written by the pipeline. Frozen-RNI results are in `data/02_output/frozen_rni/`; `rni_annual` results of the Iyer-style specification are in `06_first_stage_iyer/` and `07_table_iyer_*/`; outputs that do not use the RNI are in `06_first_stage_iyer/` (`iyer_benchmark.csv`, `goyal_panel_first_stage.csv`) and `08_kernel_validation/`.
- `slides/`: Quarto beamer deck of the paper's tables and figures with the frozen RNI (`riots_names_results.qmd`, house theme from the qmd-beamer skill). The main slides are the results table for one specification, riot exposure (`riotnear200`), and two figures of the name index; the appendix holds the summary statistics, the riot comparison, the festival and riot figure, tables that compare four specifications, and Anderson–Rubin tests for the same four specifications. `make_tables.R` writes `tables/*.tex` (laid out like the paper's tables, macros in `tables_preamble.tex`) from the targets store and the CSV files in `data/02_output/frozen_rni/06_first_stage_iyer/`; `make_figures.R` writes `figures/*.pdf` from the targets store.
- `docs/`: this file, the log and reports. `main.tex` and `Riots_and_Names.pdf` are the previous version of the paper.

## How to run

From the project root, in a shell (renv activates through `.Rprofile`):

    Rscript --no-save --no-restore -e "renv::restore()"
    Rscript --no-save --no-restore -e "targets::tar_make()"

To rebuild the slide deck after the pipeline, from the project root:

    Rscript --no-save --no-restore slides/make_tables.R
    Rscript --no-save --no-restore slides/make_figures.R
    quarto render slides/riots_names_results.qmd

Never use `Rscript --vanilla`: it skips `.Rprofile`, so renv does not activate. Install packages with `renv::install()` and then run `renv::snapshot()`. The frozen-RNI file is 2.1 GB; `get_rni_frozen_annual_raw()` aggregates it with `arrow` without loading it into memory. `_targets.R` runs fixest on one thread (`fixest::setFixest_nthreads(1)`): with the default of several threads, `tar_make()` crashed on Windows while building `anderson_rubin_iyer_path_frozen`.

## Data rules

- The frozen RNI file has one row per religion, constituency, birth year and polling booth; `mean_rni` is missing for booth cells with no scored name. `get_rni_frozen_annual_raw()` weights by the voters in scored cells.
- In both RNI versions the Andhra Pradesh file uses post-2014 constituency numbers (1–175). TCPD numbers undivided Andhra Pradesh, so 119 is added; Telangana (1–119) is coded as Andhra Pradesh. Both are handled in `get_rni_clean()`.
- Odisha is dropped in `get_rni_clean()`. In the frozen file some Odisha constituencies repeat the same voters (up to 90,139 births in one constituency-year), and the index barely separates Muslims (0.45) from Hindus (0.34) there.
- Frozen-RNI coverage gaps: Karnataka has 39 of 224 constituencies; Tamil Nadu lacks Madurai, Pudukkottai and Kanniyakumari; Assam has 84 of 126; Jammu and Kashmir only Jammu region; no Chhattisgarh.
- The `rni_annual` Maharashtra file is grouped by polling booth (ID = constituency × 10,000 + booth) with only birth years 1992 and 1994, so Maharashtra drops out of that version; the frozen file has all of Maharashtra.
- `riots_tcpd_district_mapping.xlsx` maps Goyal's `kanpur` to `uttarakhand/nainital`. `get_riots_goyal_clean()` overrides it to `uttarpradesh/kanpurnagar`.
- TCPD district names repeat across states (`pratapgarh` is in Uttar Pradesh and Rajasthan). Use state and district together as the key; the Iyer-style panels have `district_id`.
- TCPD's Assam "districts" are partly constituency or town names (30 units).
- Goyal's `fridayfestival` omits Ramnavami from Rajasthan's festival list. `fes_iyer` follows Iyer and Shrivastava's lists and matches their `fes` exactly in 1977–2001.
- The festival instrument varies only by state and year. Report the first-stage F clustered by state-year as well as by district. `fitstat(model, "ivf")`, used in `get_first_stage_table()`, is the non-robust F.
- Before 1981 the district controls (Muslim share, urbanisation, literacy, electricity, tap water) are linear back-extrapolations, not census values.

## Docs

- `docs/log_detailed.md`: one entry per piece of work (request, changes, results, checks, problems, open items, commit).
- `docs/first_stage_iyer_frozen_rni_20261019.md`: first stage, 2SLS and Anderson–Rubin results with the frozen RNI, riot years 1970–1995 (main report).
- `docs/first_stage_iyer_20261019.md`: the same analysis with the `rni_annual` files (superseded).
