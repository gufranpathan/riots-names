# Detailed log

One entry per piece of work, oldest first. Old entries are not rewritten; corrections go in new entries.

## 1. Iyer-style first stage for riot years 1970–1995, and three data fixes (2026-10-19)

- **Request:** The first stage (riot on Friday festival) is weak. Restrict to 1970–1995, adopt Iyer and Shrivastava's (2018) spatial riot kernel and their other choices to raise the first-stage F, make any other change that helps, and document everything in `docs/`.
- **Changes:**
  - New code: `R/01_festival.R` (Iyer's festival instrument `fes_iyer` from the festival dates in Goyal's monthly file), `R/01_spatial.R` (constituency map, TCPD district centroids, parent 1981 district, spatial kernel, kernel check), `R/02_iyer_data.R` (controls, panel `rni_riots_iyer`), `R/02_iyer_models.R` (six specifications, first-stage grid, LaTeX rows, Anderson–Rubin sets), `R/02_iyer_benchmarks.R` (Iyer's own data, Goyal's panel, instrument variation, panel summary).
  - New targets in `_targets.R`: `riots_monthly_path`, `iyer_robustness_path`, `ac_shapefile_paths`, `riots_monthly_raw`, `iyer_robustness_raw`, `ac_shapes`, `festival_iyer`, `district_centroids`, `district_parents`, `riot_kernel`, `district_controls`, `rni_riots_iyer`, `iv_models_iyer`, and the file targets `kernel_validation_path`, `first_stage_iyer_grid_path`, `first_stage_iyer_table_path`, `muslim_iyer_table_path`, `hindu_iyer_table_path`, `anderson_rubin_iyer_path`, `iyer_benchmark_path`, `goyal_panel_first_stage_path`, `instrument_variation_path`, `iyer_panel_summary_path`. `library(sf)` added.
  - New raw data: `data/0_raw/13-ac-shapefile/` (`India_AC.shp`, `.dbf`, `.shx`, `.prj`, `.shp.xml`, `README.md`), downloaded 2026-10-19 with `curl` from `https://raw.githubusercontent.com/datameet/maps/master/assembly-constituencies/`. License CC BY 2.5 IN.
  - Fixed in existing code (these change the original tables):
    1. `get_rni_clean()`: adds 119 to Andhra Pradesh constituency numbers and codes Telangana as Andhra Pradesh. Before, the coastal-Andhra RNI file (post-2014 numbers 1–175) was joined to TCPD numbers 1–175, which are Telangana and the northern coastal districts, and the Telangana file was dropped. Also maps `jammuandkashmir` to `jammukashmir` instead of `maharashtra` (no current effect; there is no J&K file), and keeps births up to 1996.
    2. `get_rni_riots()`: keeps riot years up to 1994 explicitly, so the original sample is unchanged by the 1996 extension.
    3. `get_riots_goyal_clean()`: maps Goyal's `kanpur` to `uttarpradesh/kanpurnagar`. The mapping file sent it to `uttarakhand/nainital`; the old filter `district != 'nainital'` then dropped both Kanpur and Nainital. Adds `state_goyal` (pre-2000 state) and a uniqueness check on state, district and year.
  - renv: installed `sf` 1.1-3 with `classInt`, `s2`, `units` and `wk`; `renv::snapshot()` now records 257 packages (the lockfile previously recorded only renv). `renv::status()` reports no issues.
- **Results:**
  - Report: `docs/first_stage_iyer_20261019.md`. Riot years 1970–1995, 11,119 district-years, 428 TCPD districts.
  - First-stage F clustered by district: 4.04 (current specification on these years) and 369.19 (Iyer's main specification, kernel `riotnear200`). Clustered by state-year: 1.68 and 4.22. The highest state-year-clustered F for 1970–1995 is 8.85 (kernel-weighted riot count, weighted by RNI sample size).
  - Iyer and Shrivastava's own Table 5 first stage: F = 164.6 clustered by district, 12.8 by state-year.
  - Riot years 1970–1976 have no first-stage relation in Goyal's panel (state-year F = 0.2). Dropping Maharashtra from that panel lowers the 1970–1995 state-year F from 9.0 to 5.8.
  - Anderson–Rubin, state-year clustering, main specification, 1970–1995: zero effect on the Muslim name index rejected (p = 0.0498; set 0.00003 to 0.945); not rejected for the Hindu name index (p = 0.329).
  - Effect of the three fixes on the original tables (riot years 1950–1994): rows 18,870 to 19,230; Andhra Pradesh districts 15 (mislabelled) to 23. First-stage F as printed in `fs_fstat_line.tex` (non-robust `ivf`), columns 1–4: 12.07, 10.74, 9.85, 0.29 before; 11.59, 10.08, 9.15, 0.04 after. District-clustered F (one-off check, not a pipeline output): 8.46, 8.43, 7.72, 0.23 before; 8.21, 8.03, 7.28, 0.03 after; state-year-clustered after: 4.39, 3.94, 3.77, 0.02. 2SLS on the Muslim index: 0.478, 0.360, 0.364, 0.358 before; 0.455, 0.355, 0.361, 0.731 after. On the Hindu index: 0.427, 0.297, 0.269, 0.788 before; 0.444, 0.282, 0.253, 1.819 after. The pre-fix output files are not kept in the repository.
- **Checks:**
  - `targets::tar_make()` completes; `tar_meta()` shows no errors or warnings.
  - `get_rni_riots_iyer()` stops unless `fes_iyer` equals Iyer's `fes` in every row with Iyer data (1977–1995 in the panel), keys are unique and key variables have no missing values.
  - The kernel formulas reproduce Iyer's file: `riotnear200` from `riotneardist` to within 5e-8; `riotall200` and `fesnormdist200` correlate 0.97–0.98 and 0.99 with Iyer's when rebuilt from our centroids (scratch check on sample years 1982, 1988 and 1993). The rebuilt `riotnear200` correlates 0.975 with Iyer's on their districts in 1977–2001 (`08_kernel_validation/`).
  - The analytic Anderson–Rubin sets agree with a grid-search inversion in a scratch script on a prototype of the panel (for example 0.004 to 1.036 against 0.00003 to 0.945; the prototype keyed districts by name and used single-equation small-sample corrections).
  - Not checked: Iyer and Shrivastava's published first-stage F-statistics against the paper's tables (only their do-files and data were available).
- **Problems:**
  - The kernel raises the first-stage F only under district clustering. Under state-year, two-way or year clustering it does not beat the own-district riot dummy in 1970–1995.
  - Exploratory changes that did not raise the state-year-clustered F (scratch scripts, not kept; F for 1970–1995 / 1977–1995, main controls and trend): number of festivals on a Friday (0–5) as the instrument, 0.85 / 5.98; two instruments (state festivals; Dushehra or Diwali), 7.59 / 4.38; adding `fes` times pre-1970 kernel exposure, 2.26 / 4.35; adding `fes` times Muslim share, 2.12 / 4.94; own riot with `fes` times the pre-1970 riot share, 2.51 / 3.14; interactions with state-year fixed effects, 0.12 to 2.31; districts with Muslim share at or above the median, 2.57 / 4.96, below the median, 4.47 / 9.70, at least 5%, 3.26 / 5.80.
  - Iyer's coordinates are not in their files; centroids of 2008 districts give a median distance error of 16 km against their `riotneardist`. Large errors occur in years with few riots, where the kernel is near zero.
  - The DataMeet README says Assam, Jharkhand, Jammu and Kashmir, Manipur, Nagaland and Arunachal Pradesh have pre-delimitation boundaries. Constituency names still match TCPD by number in all states (97–100%), so the join by number was kept.
  - Iyer's `fes` is 0 for 1976 in every state because their file has no festival dates for that year; Navami (1 October) and Diwali (22 October 1976) fell on Fridays.
- **Open:**
  1. Rebuild the Maharashtra RNI file from the raw rolls, grouped by constituency and keeping all birth years.
  2. Decide which first-stage F (district or state-year clustering) and which window (1970–1995 or 1977–1995) the paper reports.
  3. The original models use the district name alone as the fixed effect and cluster, which merges Pratapgarh (Uttar Pradesh) and Pratapgarh (Rajasthan); not changed.
  4. The original first-stage table prints the non-robust F (`fitstat(..., "ivf")`); not changed.
  5. Correct the `kanpur` row in `data/0_raw/01-riots/riots_tcpd_district_mapping.xlsx`; the code override stays until then.
  6. Karnataka has 39 of 224 constituencies in the RNI data; Odisha is excluded by design.
- **Commit:** ebc3ec5 (branch `frozen-rni-iyer-first-stage`).

## 2. Frozen RNI added as the main outcome; Iyer-style analysis rerun and new report (2026-10-19)

- **Request:** New RNI data with a "frozen" index (names scored on births before 1970) in the CEGA Dropbox folder `Riot Names Data/data/0_raw/segregation data 2026`. Use it, keep the old RNI in the code, rerun the tests and write a new report that stands alone, without reference to the earlier data and results.
- **Changes:**
  - Data: copied `segegation_analysis.csv` (2.1 GB, file dated 2026-10-17) to `data/0_raw/segregation data 2026/`, mirroring the Dropbox layout; `cmp` confirms the copy is byte-identical.
  - Code: `R/01_rni_read.R` gains `get_rni_frozen_annual_raw()` (aggregates the 35.1 million booth rows with `arrow` to 196,437 constituency × birth year × religion rows), `get_rni_frozen_clean()` and `get_rni_frozen_district()` (wrappers around the unchanged `get_rni_clean()` and `get_rni_district()`), and `get_rni_frozen_coverage()`.
  - `get_district_parents()` no longer takes `rni_district`; it covers every TCPD district in the 16 riot-data states, so `district_parents` and `riot_kernel` are shared by both RNI versions.
  - The Iyer-style output functions take an `output_root` argument: `get_first_stage_iyer_grid()`, `get_first_stage_iyer_table()`, `get_iyer_model_tables()`, `get_anderson_rubin_iyer()`, `get_instrument_variation()` and `get_iyer_panel_summary()`, which also writes `iyer_panel_by_state.csv` now.
  - `_targets.R`: new targets `rni_frozen_path`, `rni_frozen_annual_raw`, `rni_frozen_clean`, `rni_frozen_district` and `rni_frozen_coverage_path`. The per-RNI Iyer-style targets are generated by `tar_map()` with the suffixes `_frozen` (outputs in `data/02_output/frozen_rni/`) and `_annual` (outputs in the existing folders). Renamed: `rni_riots_iyer` to `rni_riots_iyer_annual`, `iv_models_iyer` to `iv_models_iyer_annual`, and the seven file targets of that branch likewise. The objects stored under the old names stay in `_targets/objects` until `targets::tar_prune()` is run.
  - Docs: new report `docs/first_stage_iyer_frozen_rni_20261019.md`; `docs/first_stage_iyer_20261019.md` marked as superseded; `docs/README.md` updated.
- **Results:**
  - Frozen RNI: births 1971–1997; religions Hindu and Muslim only; voter-weighted mean RNI 0.755 for Muslims and 0.207 for Hindus; 65.5% of Hindu and 57.0% of Muslim voters are in booth cells with a score.
  - Panel `rni_riots_iyer_frozen`: 12,161 district-years, 468 districts (285 on the 1981 list), 15 pre-2000 states, riot years 1970–1995. Maharashtra (35 districts, 100 riot district-years) and Jammu region enter. The `rni_annual` panel has 11,119 district-years, 428 districts and 13 states.
  - First-stage F for 1970–1995, columns 1–6. Clustered by district: 11.46, 17.32, 417.56, 435.48, 344.87, 81.92. Clustered by state-year: 4.20, 7.28, 4.98, 5.40, 11.18, 2.79 (`rni_annual`: 1.68, 4.10, 3.96, 4.22, 8.34, 2.23).
  - 2SLS in the main specification, 1970–1995: Muslim index 0.0233 (SE 0.0085 by district, 0.0309 by state-year), Hindu index 0.0215 (0.0033, 0.0188). Anderson–Rubin p of a zero effect with state-year clustering: 0.444 and 0.197 (`rni_annual`: 0.0498 and 0.329). For 1977–1995 the effects are not significant under district clustering either (p = 0.130 and 0.240).
- **Checks:**
  - `targets::tar_make()` completes; 25 targets rebuilt on the first run. The `_annual` branch reproduces the earlier first-stage F-statistics and panel summary exactly (for example 369.19 by district and 4.22 by state-year in column 4).
  - One warning: `fixest` adjusted a two-way-clustered covariance matrix that was not positive semi-definite, in the weighted `riotall200` variant of the first-stage grid (both windows). The report flags those two F-statistics.
  - Screen of the frozen file for duplicated records: Odisha has constituency-year counts that are near-exact multiples of about 4,097 and booth counts that double in some years (constituency 7: 242 to 483 booths), and stays excluded. Elsewhere, Hindu booth counts above 1.5 times a constituency's median occur in Assam (23 constituencies), Telangana (26), West Bengal (12) and Bihar (5). The cases inspected have 5 to 60 voters a year, which points to sparse coverage rather than duplication; not every flagged constituency was inspected.
- **Problems:**
  - Birth-year counts within constituencies swing from year to year in most states, consistent with age heaping in the rolls; birth years are noisy.
  - The original specification (riot years 1950–1994) cannot use the frozen RNI, which starts with 1971 births; it still runs on `rni_annual`.
- **Open:**
  1. Deduplicate Odisha and fill the frozen-RNI coverage gaps upstream (Karnataka, Madurai, Pudukkottai, Kanniyakumari, Assam, the Kashmir valley, Chhattisgarh).
  2. Decide whether `riotall200` (state-year F 11.2) replaces `riotnear200` (5.4) as the main endogenous variable.
  3. Items 2–6 of entry 1 remain open; item 1 (Maharashtra) is resolved in the frozen RNI.
- **Commit:** ebc3ec5 (branch `frozen-rni-iyer-first-stage`).

## 3. Slide deck of the paper's tables and figures with the frozen RNI (2026-10-19)

- **Request:** A Quarto deck rendered to PDF (qmd-beamer and simple-prose skills) showing only the tables and figures of the previous version of the paper (`docs/main.tex`, `docs/Riots_and_Names.pdf`), one per slide. The user chose the frozen-RNI results in the paper's layout, then asked for LaTeX tables.
- **Changes:**
  - New folder `slides/`: `riots_names_results.qmd` (title and 8 slides), `beamer_theme.tex` and `beamer.lua` (copies of the skill's house theme), `tables_preamble.tex` (macros for the LaTeX tables), `make_tables.R` (writes `tables/*.tex` from the targets `rni_riots_iyer_frozen`, `iv_models_iyer_frozen` and `riots_goyal_clean`) and `make_figures.R` (writes `figures/*.pdf` from `rni_riots_iyer_frozen`).
  - The paper's four columns map to specifications 1, 2, 4 and 5 of the Iyer-style grid: own riot with district fixed effects and Goyal's festival coding; own riot with Iyer and Shrivastava's coding, controls and quadratic trend; `riotnear200`; `riotall200`. The tables add standard errors clustered by state-year (in brackets) and the state-year-clustered first-stage F; the effects tables drop the paper's R-squared row.
  - The paper's Table 1 is split into two slides (Panel A, Panel B). Rows and figure panels that use own-district riots are limited to the 285 districts on the 1981 list.
  - `slides/beamer_theme.tex`: `Ligatures=TeX` added to `\headingfont` and `\subheadingfont`, which printed pandoc's `--` (an en dash) as two hyphens. The skill's own copy (`~/.claude/skills/qmd-beamer/assets/house/beamer_theme.tex`) still lacks it.
  - `docs/README.md`: `slides/` and the deck's build commands added.
- **Results:** `slides/riots_names_results.pdf`, 9 pages.
- **Checks:** `make_tables.R` stops unless its first-stage F-statistics equal those in the pipeline's `first_stage_iyer_grid.csv` (frozen RNI). `check_deck.py`: 9 pages as expected, no overflow, wide lines, missing characters or dead links; every page viewed.
- **Problems:** the first build had an empty frame made by an HTML comment before the first slide; the comment moved into the YAML. The first build took 464 s (font cache); later builds take 20–30 s.
- **Open:** the deck's text slides; whether the effects tables should keep the paper's R-squared row.
- **Commit:** ebc3ec5 (branch `frozen-rni-iyer-first-stage`).

## 4. Deck tables in the paper's layout; one main specification; appendix by specification (2026-10-19)

- **Request:** Make the deck's tables look like the paper's (`docs/Riots_and_Names.pdf`); use distance-weighted riot exposure as the main and only specification, with the Muslim and Hindu indices in one table; put the other specifications in an appendix.
- **Changes:**
  - `slides/tables_preamble.tex` rewritten: Latin Modern (the 7-point design, `lmroman7`) in black, booktabs rules, an `econtable` environment (threeparttable, centred at natural width) and `\econnotes{}` for an italic "Notes:" paragraph at the table's width; `\sym{}` for stars that do not move the number; `\ses{}{}` for two standard errors in one cell.
  - `slides/make_tables.R` rewritten to write the paper's layouts: double rules and bold panel headers in the two summary tables, italic group labels, (1)-(4) column numbers, Panels A-C, Observations and R-squared, and specification rows. The main first stage and the main results table use specification 4 (`riotnear200`); the results table has the Muslim and Hindu indices as columns (1) and (2). Appendix tables `app_first_stage.tex`, `app_effects_muslim.tex` and `app_effects_hindu.tex` compare specifications 1, 2, 4 and 5. The state-year-clustered standard error sits next to the district-clustered one, in brackets. The summary table drops the riot count and Goyal's festival coding.
  - `slides/riots_names_results.qmd`: notes moved into the tables; the two effect slides replaced by one ("Effect of riot exposure on names"); an appendix with three slides.
- **Results:** `slides/riots_names_results.pdf`, 12 pages (title, 7 main slides, the appendix divider, 3 appendix slides).
- **Checks:** `check_deck.py`: 12 pages as expected, no overflow, wide lines, missing characters or dead links; every page viewed. `make_tables.R` still stops unless its first-stage F-statistics equal the pipeline grid.
- **Problems:** at first the results table was 43.6 pt too tall and the appendix effect tables 24.9 pt too tall; putting both standard errors on one row and tightening line spacing fixed it. Fixed-width columns made the appendix tables too wide; narrower columns, shorter F labels and natural-width columns in the appendix first stage fixed it.
- **Open:** the deck's text slides.
- **Commit:** ebc3ec5 (branch `frozen-rni-iyer-first-stage`).

## 5. Deck reordered; one standard error per line; Anderson-Rubin named in the notes (2026-10-19)

- **Request:** Reorder the deck to slide 8 (results), 4 and 5 (name-index figures), then slides 2 and 3 in the appendix and the first stage (slide 6) in the appendix with all specifications. Put the bracketed standard errors on their own line; say whether the reduced-form test is the Anderson-Rubin test and add it to the notes. The user also asked whether state-year clusters are used, and to drop the state-year F row if not.
- **Changes:**
  - `slides/riots_names_results.qmd`: main slides are "Effect of riot exposure on names", "Name index by birth cohort" and "Distribution of the name index"; the appendix holds "Summary statistics", "Riot and non-riot district-years", "Friday festivals and riots by year", "First stage by specification" and the two effect tables by specification. Slide 7 (festivals and riots by year) was not in the requested order and went to the appendix after the riot comparison. The one-column first-stage slide was removed; the results note now defines riot exposure, the instrument and the controls, and the appendix first-stage note defines the instrument and controls.
  - `slides/make_tables.R`: each bracketed (state-year) standard error on its own line in all regression tables; IV R-squared rows dropped; in the main table the three all-"Yes" specification rows became one row, and in the appendix effect tables "Controls" and "Quadratic Year Trend" share a row (asserted equal); the one-column first-stage table is no longer written. `slides/tables_preamble.tex`: the side-by-side `\ses` macro removed.
  - Notes: with one instrument the reduced-form t-test is the Anderson-Rubin test of a zero effect (district clustering in parentheses, state-year in brackets); the results and appendix effect notes now say so.
  - State-year clustering is used for the bracketed standard errors and the second F row, so the row stays (the user's condition for removing it did not hold).
- **Results:** `slides/riots_names_results.pdf`, 11 pages: title, 3 main slides, the appendix divider and 6 appendix slides.
- **Checks:** `check_deck.py`: 11 pages as expected, no overflow, wide lines, missing characters or dead links; page titles confirmed with `pdftotext`; pages 2, 9 and 10 viewed.
- **Problems:** the reordered results slide was 10.9 pt too tall with the longer note; dropping the IV R-squared row and merging the identical specification rows made room for the separate bracket rows. The appendix effect tables needed 6.3 pt type (from 6.4 pt).
- **Open:** where slide 7 (festivals and riots by year) belongs; whether to report district clustering only, which would remove the brackets and the state-year F row.
- **Commit:** ebc3ec5 (branch `frozen-rni-iyer-first-stage`).

## 6. Main results slide clustered by district only (2026-10-19)

- **Request:** Remove the state-year results (bracketed standard errors and "First-stage F, state-year clusters") from the main slide; keep them in the appendix. The user had read "state-year clusters" as state fixed effects; the model has district fixed effects only, and state-year is a second way to cluster the standard errors.
- **Changes:** `slides/make_tables.R`: `estimate_panels()` takes `state_year = FALSE` for the main table, which now shows only district-clustered standard errors and one "First-stage F-statistic" row; the three specification rows (Controls, Quadratic Year Trend, District FE) are separate again now that there is room. Appendix tables unchanged. `slides/riots_names_results.qmd`: the results note drops the brackets and says the appendix adds state-year clusters.
- **Checks:** `check_deck.py`: 11 pages as expected, no overflow, wide lines, missing characters or dead links; page 2 viewed; the appendix tables still hold the bracketed rows and the state-year F rows.
- **Commit:** ebc3ec5 (branch `frozen-rni-iyer-first-stage`).

## 7. Anderson–Rubin tests by specification in the deck's appendix (2026-10-19)

- **Request:** Add the Anderson–Rubin (AR) results to the appendix slides only. The user had asked where the AR values were shown (the appendix notes named the test, but no slide reported its p-values or sets) and whether the test concerns the IV estimate. It does: the AR test checks a value of the IV effect, and with one instrument the test of a zero effect is the reduced-form t-test.
- **Changes:**
  - `R/02_iyer_models.R`: `get_anderson_rubin_iyer()` covers specification 1 (Goyal's festival coding, own riot, no controls or trend) as well as 2, 4 and 5, so the AR results cover the four appendix columns. `anderson_rubin_iyer.csv` gains the specification 1 rows in `data/02_output/frozen_rni/06_first_stage_iyer/` and in `data/02_output/06_first_stage_iyer/`. The main-specification numbers equal those in entry 2.
  - `_targets.R`: `fixest::setFixest_nthreads(1)` after the libraries. With fixest's default thread count, `tar_make()` crashed while building `anderson_rubin_iyer_path_frozen` ("callr subprocess failed: could not start R, exited with non-zero status, has crashed or was killed"). Run in the same process (`callr_function = NULL`), R exited with code 127. The same function call ran without error outside targets. With one thread the pipeline completed. The setting applies to every target.
  - `slides/make_tables.R`: writes `slides/tables/app_anderson_rubin.tex` from `anderson_rubin_iyer.csv` (riot years 1970–1995). For each outcome it gives the IV estimate, the AR p-value of a zero effect and the AR 95% set, each with district and with state-year clusters. It stops unless the file's IV estimates equal those in the appendix effect tables.
  - `slides/riots_names_results.qmd`: new last slide "Anderson–Rubin tests by specification" (`#app-anderson-rubin`). The notes of the two appendix effect tables end "the last table reports their p-values and 95% sets". The main slides are unchanged.
- **Results:** `slides/riots_names_results.pdf`, 12 pages. In the main specification (column 3, riot exposure):
  - Muslim name index: IV 0.0233; AR p = 0.007 with district clusters and 0.444 with state-year clusters; AR 95% sets [0.0066, 0.0402] and [−0.0585, 0.1827].
  - Hindu name index: IV 0.0215; AR p < 0.001 and 0.197; sets [0.0151, 0.0282] and [−0.0133, 0.1595].
  - With state-year clusters no column rejects a zero effect at the 5% level (p from 0.197 to 0.720), and every set contains zero. With district clusters every column rejects it except column 1 for the Muslim index (p = 0.194).
  - Columns 2–4 have the same instrument, controls and sample, so they share the reduced form and the AR p-value; their sets differ because the riot measures have different scales.
- **Checks:** `tar_make()` completed with one thread; `tar_outdated()` returns no targets. `make_tables.R` ran, including the check of the IV estimates. `check_deck.py`: 12 pages as expected, no overflow, wide lines, missing characters or dead links; pages 10–12 viewed.
- **Problems:** the crash above; its cause was not found, and the one-thread setting avoids it. With the specification rows (festival coding, controls, fixed effects) the AR table did not fit the slide, so they were dropped and the note refers to the first-stage slide for the columns.
- **Open:** none new; where slide 7 (festivals and riots by year) belongs is still open (entry 5).
- **Commit:** 2ed98e4 (branch `master`).
