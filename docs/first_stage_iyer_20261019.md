Superseded by `docs/first_stage_iyer_frozen_rni_20261019.md` (2026-10-19), which uses the frozen name index. This report uses the `rni_annual` files; its targets now carry the suffix `_annual` (for example `rni_riots_iyer_annual`).

# Does Iyer and Shrivastava's design give a strong first stage for riot years 1970–1995?

2026-10-19. Claude Code session for Gufran Pathan.

## Answer

Following Iyer and Shrivastava (2018) on riot years 1970–1995 raises the first-stage F-statistic from 4.0 (the current specification on the same years) to 369 when standard errors are clustered by district, as they do. Their festival coding, controls and time trend raise it to 8.2; their spatial riot kernel does the rest.

The instrument varies only by state and year. Clustered by state-year, the main specification has F = 4.2, and no specification of the 1970–1995 sample reaches 10 (the best is 8.9, for the kernel-weighted riot count). Iyer and Shrivastava's own first stage falls from 164.6 to 12.8 under the same change.

Two data limits explain most of the gap with their paper: riot years 1970–1976 carry no first-stage relation, and Maharashtra is missing from the RNI data. With state-year clustering, the Anderson–Rubin test rejects a zero effect on the Muslim name index (p = 0.0498, 95% set 0.00003 to 0.945) but not on the Hindu name index (p = 0.33).

## Terms

- **First-stage F**: the Wald F-statistic of the excluded instrument in the first stage, computed with the stated clustering. With one instrument and one endogenous variable it equals the Kleibergen–Paap F that Iyer and Shrivastava report.
- **1981 districts**: the 339 districts in 16 states used by Iyer and Shrivastava (2018) and by Goyal and van Noort (2025). Their riot data are identical for 1977–2001.
- **TCPD districts**: the districts of the TCPD 2008 (Delim4) constituency-to-district mapping. The religious name index (RNI) outcome is aggregated to these districts.
- **Riot year t**: riots, the instrument and BJP rule are measured in year t; the outcome is the RNI of people born in t+1.

## What Iyer and Shrivastava do

The replication files are in `data/0_raw/01-riots/iyer/Replication/`. Their main first stage ("Tables 1-8 Figure 1.do", Table 5) is:

`L.riotnear200 = L.fes + L.bjprule + muslim + urb + lit + ele + tap + time + tsq + district FE`, on years with a state election, clustered by district.

1. `riotnear200 = exp(-d^2 / (2 * 200^2))`, where d is the distance in km from the district to the nearest district with a riot that year, and d = 0 if the district had one. This formula reproduces their `riotnear200` from their `riotneardist` to within 5e-8. Table 3 uses bandwidths of 100 to 300 km.
2. `fes = 1` if any of the state's three main Hindu festivals, Dushehra or Diwali falls on a Friday. Their variable `fesfri` ("Tables 11, 12.do") equals `fes` in every row.
3. The controls are BJP rule of the state in the riot year, and the Muslim share, urbanisation, literacy, electricity and tap water in the election year, with a quadratic time trend.
4. Table 6 replaces the kernel with `riotall200`, the kernel-weighted count of riots, instrumented by `fesnormdist200`, the kernel-weighted sum of the festival dummies of all districts, with year fixed effects.

Goyal and van Noort (2025, *Journal of Conflict Resolution*) extend `fes` to 1950–2006 as `fridayfestival` for the same 339 districts. Their file contains `riotnear100` only for 1977–2001, so the kernel had to be rebuilt for 1970–1976.

## Data and method

The new analysis panel is `rni_riots_iyer` (target in `_targets.R`; function in `R/02_iyer_data.R`). It has 11,119 district-years: 428 TCPD districts in 13 states (as of 1990), riot years 1970–1995. Of the 428 districts, 256 match a 1981 district by name. The others were created after 1981 and lie a median 51 km from the nearest 1981 district (file: `iyer_panel_summary.csv`).

1. Kernel (`R/01_spatial.R`). District centroids come from the DataMeet assembly-constituency shapefile (2008 delimitation; CC BY 2.5 IN; downloaded 2026-10-19 from <https://github.com/datameet/maps/tree/master/assembly-constituencies>). Constituencies are matched to TCPD by state and number; the shapefile and TCPD names agree for 97–100% of constituencies in every state. Riots come from Goyal's 339 districts, each placed at the centroid of the TCPD district with its name. `riotnear100` to `riotnear300`, `riotall200` and `fesnormdist200` follow Iyer's formulas.
2. Own-district riots (`riot`) are known only for the 256 districts on the 1981 list; they are 0 elsewhere, as in the existing pipeline. The kernel covers all 428 districts, because a district created after 1981 is close to its parent district.
3. Instrument (`R/01_festival.R`). `fes_iyer` applies Iyer's festival lists to the festival dates in Goyal's monthly file (`Riots_DistxMMYY.dta`). It equals Iyer's `fes` in every row for 1977–2001. It differs from Goyal's `fridayfestival` only for Rajasthan in 1955, 1959, 1962, 1982, 1986, 1989 and 2003, years in which Ramnavami fell on a Friday; Goyal's Rajasthan list omits Ramnavami. Iyer's `fes` is 0 in 1976 for every state because their file has no festival dates for 1976.
4. Controls (`R/02_iyer_data.R`). Muslim share, urbanisation, literacy and electricity come from Goyal (1971 onward) and tap water from Iyer (1981 onward). Goyal's 1971–1980 values are the 1981–1991 linear trend of each district extended backwards; the same rule extends all five to 1969. Before 1981 they are therefore trends, not census values, and some are negative. BJP rule is 0 before 1977. Districts not on the 1981 list take the controls and festival list of the nearest 1981 district in the same state.
5. Specifications (`R/02_iyer_models.R`). All have district fixed effects. Columns 2–5 add Iyer's quadratic trend; columns 2 and 4–6 add Iyer's controls. Column 1 is the existing pipeline's model 2 (district fixed effects only) on the new sample.

Missing from the outcome data: Maharashtra (the RNI file is grouped by polling booth and covers only birth years 1992 and 1994), Odisha (dropped in `get_rni_clean()` for implausible voter counts) and most of Karnataka (39 of 224 constituencies).

## Results

### Table 1. First stage, riot years 1970–1995

N = 11,119 district-years, 428 districts, 338 state-years. Source: `data/02_output/06_first_stage_iyer/first_stage_iyer_grid.csv` (the LaTeX rows of the same table are the `fs_iyer_*_line.tex` files in that folder).

| | (1) | (2) | (3) | (4) | (5) | (6) |
|---|---|---|---|---|---|---|
| Endogenous variable | riot | riot | riotnear200 | riotnear200 | riotall200 | riotall200 |
| Instrument | fridayfestival | fes_iyer | fes_iyer | fes_iyer | fes_iyer | fesnormdist200 |
| Coefficient | 0.0061 | 0.0090 | 0.0607 | 0.0611 | 0.898 | 0.0203 |
| Iyer controls | No | Yes | No | Yes | Yes | Yes |
| Quadratic trend | No | Yes | Yes | Yes | Yes | No |
| Year fixed effects | No | No | No | No | No | Yes |
| F, clustered by district (Iyer) | 4.04 | 8.20 | 374.68 | 369.19 | 296.99 | 67.59 |
| F, clustered by state-year | 1.68 | 4.10 | 3.96 | 4.22 | 8.34 | 2.23 |
| F, two-way (district and state-year) | 1.66 | 3.96 | 4.23 | 4.50 | 8.69 | 2.35 |
| F, clustered by year | 0.80 | 2.05 | 1.73 | 1.84 | 4.18 | 0.89 |

Column 4 is Iyer's main specification. Moving from column 2 to column 4 replaces the own-district riot with the kernel; the district-clustered F rises from 8.2 to 369, while the state-year-clustered F stays near 4.

### Why the clustering level matters

The instrument takes one value per state and year. In 6 of the 26 years every state has a Friday festival, and in 6 years no state has one; year fixed effects explain 61% of its variance (`instrument_variation.csv`). Clustering by district treats the districts of a state-year as independent, although they share the instrument value.

The kernel adds to this. One riot raises `riotnear200` in every district within a few hundred kilometres, so first-stage errors are correlated across districts in the same state-year. Abadie, Athey, Imbens and Wooldridge (2023, *Quarterly Journal of Economics*) recommend clustering at the level at which the instrument is assigned, here the state-year. State clustering (13 clusters) is too coarse for cluster-robust inference and is reported only in the CSV.

### Table 2. The same diagnostics on Iyer and Shrivastava's data

Source: `iyer_benchmark.csv`. Rows 1–2 reproduce their Table 5 first stage from `dataset_robustness.dta`.

| Specification | N | F, district | F, state-year | F, two-way | F, year |
|---|---|---|---|---|---|
| Table 5 col. 2: riotnear200, election years | 1,333 | 164.6 | 12.8 | 16.9 | 12.4 |
| Table 5 col. 4: riot, election years | 1,333 | 19.4 | 9.9 | 11.8 | 6.5 |
| riotnear200, all years 1977–1995 | 6,441 | 374.8 | 11.4 | 12.5 | 7.1 |
| riot, all years 1977–1995 | 6,441 | 29.2 | 12.3 | 12.7 | 7.9 |

Their first stage shows the same drop from district to state-year clustering, but stays above 10.

### Table 3. Which years and states carry the first stage

Goyal's 339-district panel, all 16 states, `riot ~ fes_iyer + quadratic trend + district FE`. Source: `goyal_panel_first_stage.csv`.

| Riot years | States dropped | F, district | F, state-year | F, two-way |
|---|---|---|---|---|
| 1950–1995 | none | 20.0 | 8.9 | 8.4 |
| 1970–1995 | none | 23.4 | 9.0 | 9.1 |
| 1977–1995 | none | 29.2 | 12.3 | 12.7 |
| 1970–1976 | none | 0.5 | 0.2 | 0.3 |
| 1950–2006 | none | 32.4 | 11.6 | 11.6 |
| 1970–1995 | Maharashtra | 13.5 | 5.8 | 5.7 |
| 1970–1995 | Maharashtra, Orissa | 12.8 | 5.5 | 5.4 |
| 1977–1995 | Maharashtra | 19.8 | 9.2 | 9.2 |

Riot years 1970–1976 have no first-stage relation, so adding them to 1977–1995 lowers the F-statistic. Among single states, dropping Maharashtra lowers the 1970–1995 state-year F the most (from 9.0 to 5.8); the CSV lists all 16.

### Table 4. Variants of the main specification

F-statistics clustered by district and by state-year. Source: `first_stage_iyer_grid.csv`.

| Variant of column 4 | 1970–95, district | 1970–95, state-year | 1977–95, district | 1977–95, state-year |
|---|---|---|---|---|
| Main specification | 369.2 | 4.22 | 559.6 | 8.64 |
| Bandwidth 100 km | 140.0 | 5.35 | 196.7 | 8.10 |
| Bandwidth 150 km | 263.9 | 4.82 | 372.6 | 8.64 |
| Bandwidth 250 km | 377.4 | 3.71 | 701.4 | 8.54 |
| Bandwidth 300 km | 327.5 | 3.25 | 791.9 | 8.45 |
| Goyal's fridayfestival as instrument | 261.5 | 3.44 | 443.7 | 7.46 |
| Districts on the 1981 list only | 213.7 | 4.05 | 357.9 | 9.18 |
| Year fixed effects instead of trend | 1.53 | 0.09 | 2.75 | 0.16 |
| Weighted by RNI sample size | 393.3 | 5.67 | 467.7 | 10.77 |
| riotall200 (column 5) | 297.0 | 8.34 | 345.7 | 8.71 |
| riotall200, weighted by RNI sample size | 235.1 | 8.85 | 246.6 | 8.70 |

The kernel-weighted riot count and weighting by sample size help most under state-year clustering. Year fixed effects remove the variation the instrument has. Exploratory checks that did not help are listed in `docs/log_detailed.md`, entry 1.

### Table 5. Second stage

2SLS coefficient, with the standard error clustered by district in parentheses and by state-year in brackets. Source: `07_table_iyer_muslim/` and `07_table_iyer_hindu/` (`iyer_iv_*_line.tex`).

| Outcome (births in t+1) | (1) | (2) | (3) | (4) | (5) | (6) |
|---|---|---|---|---|---|---|
| Muslim name index | 0.2669 | 0.2608 | 0.0350 | 0.0382 | 0.0026 | 0.0037 |
| | (0.1648) | (0.1141) | (0.0101) | (0.0103) | (0.0007) | (0.0021) |
| | [0.2782] | [0.1861] | [0.0268] | [0.0272] | [0.0016] | [0.0049] |
| Hindu name index | -0.0687 | 0.1156 | 0.0147 | 0.0169 | 0.0012 | 0.0044 |
| | (0.0558) | (0.0464) | (0.0040) | (0.0041) | (0.0003) | (0.0012) |
| | [0.2872] | [0.1295] | [0.0202] | [0.0188] | [0.0012] | [0.0050] |

Columns differ in the scale of the endogenous variable. In column 4, a district that goes from no riot nearby (`riotnear200` = 0) to a riot of its own (`riotnear200` = 1) has a Muslim name index 0.038 higher in the next birth cohort. The sample mean of that index is 0.76.

### Table 6. Inference that remains valid with a weak instrument

With a weak first stage, the usual 2SLS t-test is unreliable. The Anderson–Rubin set is valid at any instrument strength (Andrews, Stock and Sun 2019, *Annual Review of Economics*). With one instrument, its test of a zero effect is the reduced-form t-test. Main specification (column 4); source: `anderson_rubin_iyer.csv`, which also covers columns 2 and 5 and two-way clustering.

| Riot years | Outcome | 2SLS | p, state-year SE | AR 95% set, district | AR 95% set, state-year | AR p of zero effect, state-year |
|---|---|---|---|---|---|---|
| 1970–1995 | Muslim | 0.0382 | 0.160 | 0.018 to 0.059 | 0.00003 to 0.945 | 0.0498 |
| 1970–1995 | Hindu | 0.0169 | 0.369 | 0.009 to 0.025 | -0.026 to 0.402 | 0.329 |
| 1977–1995 | Muslim | 0.0205 | 0.126 | 0.005 to 0.036 | -0.006 to 0.068 | 0.111 |
| 1977–1995 | Hindu | 0.0162 | 0.193 | 0.010 to 0.022 | -0.008 to 0.060 | 0.172 |

With state-year clustering, the effect on Muslim names in 1970–1995 is positive at the 5% level, but its size is not pinned down: the set runs from about zero to 0.945. The other three effects are not distinguishable from zero.

### Check of the rebuilt kernel

Iyer's 339 districts in 1977–2001 (8,475 district-years), with the kernel rebuilt from AC-map centroids and Goyal's riots. Source: `data/02_output/08_kernel_validation/` (CSV and scatter plot).

| Statistic | Value |
|---|---|
| Correlation of distance to nearest riot with Iyer's | 0.975 |
| Correlation of riotnear200 with Iyer's | 0.975 |
| Median absolute distance error | 16 km |
| 90th / 95th percentile of the distance error | 52 km / 66 km |
| Mean absolute difference in riotnear200 | 0.046 |
| fes_iyer equal to Iyer's fes (1977–2001) | 100% of rows |

The largest distance errors occur in years with few riots, such as 1994 (7 riots), when the nearest riot is 400 to 1,500 km away and the kernel is close to zero under either set of coordinates. Iyer and Shrivastava's coordinates are not in their files.

## Caveats

1. The kernel estimates the effect of exposure to nearby riots, not of a riot in one's own district. The exclusion restriction must hold for the whole area within a few hundred kilometres.
2. Choosing a specification because its F-statistic is large biases inference after the choice. All variants tried are reported here and in the log.
3. The rebuilt kernel uses centroids of 2008 districts and Goyal's riot districts only (as Iyer did); riots in Delhi or other states outside the 16 are not counted.
4. TCPD's district names for Assam are partly constituency or town names (30 units), so Assam's units are not districts.
5. The 2SLS standard errors in Table 5 use the default small-sample corrections of `fixest`; Iyer's `xtivreg2` estimates use none, so their numbers can differ slightly.

## Recommendations

1. Report the first-stage F clustered by state-year (or two-way) next to the district-clustered F, and base inference on the Anderson–Rubin sets in `anderson_rubin_iyer.csv`.
2. Rebuild the Maharashtra RNI file from the raw rolls, grouped by constituency and keeping all birth years. In Goyal's panel, Maharashtra alone moves the state-year F from 5.8 to 9.0.
3. Report riot years 1977–1995 alongside 1970–1995. The earlier years add observations but no first-stage variation.
4. Consider `riotall200` (column 5). With or without weights, it has the largest state-year-clustered F in the 1970–1995 sample (8.3 and 8.9).

## Files

- Code: `R/01_festival.R`, `R/01_spatial.R`, `R/02_iyer_data.R`, `R/02_iyer_models.R`, `R/02_iyer_benchmarks.R`; targets in the section "Iyer & Shrivastava (2018) style first stage" of `_targets.R`.
- Run: `Rscript --no-save --no-restore -e "targets::tar_make()"` from the project root.
- Outputs: `data/02_output/06_first_stage_iyer/` (CSV files and first-stage LaTeX rows), `data/02_output/07_table_iyer_muslim/` and `07_table_iyer_hindu/` (OLS, reduced-form and 2SLS LaTeX rows), `data/02_output/08_kernel_validation/`.
- New raw data: `data/0_raw/13-ac-shapefile/` (DataMeet assembly constituencies).
