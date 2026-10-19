# How strong is the Friday-festival first stage, and what are the IV estimates, with the frozen name index?

2026-10-19. Claude Code session for Gufran Pathan.

## Answer

The sample has 12,161 district-years: 468 districts in 15 states (as of 1990), riot years 1970–1995, with name outcomes for people born a year later. With Iyer and Shrivastava's (2018) design and standard errors clustered by district, as in their paper, the first-stage F-statistic is 435.

The instrument varies only by state and year. Clustered by state-year, their main specification has F = 5.4. The kernel-weighted count of nearby riots is the only endogenous variable above 10: F = 11.2 by state-year and 11.6 with two-way clustering.

The 2SLS effects of riot exposure on both name indices are positive. They are significant with district clustering but not with state-year clustering. The weak-instrument-robust (Anderson–Rubin) test of a zero effect gives p = 0.44 for the Muslim index and p = 0.20 for the Hindu index. For riot years 1977–1995 the effects are not significant even with district clustering.

## Terms

- **Religious name index (RNI)**: a score between 0 and 1 for each name that rises with how typically Muslim the name is. In this data the scores are frozen: they are computed from voters born before 1970 and held fixed for later cohorts. Voters whose names have no pre-1970 score drop out of the averages.
- **Muslim name index**: the mean RNI of Muslim voters born in a district and year. Higher values mean more distinctively Muslim names.
- **Hindu name index**: one minus the mean RNI of Hindu voters born in a district and year. Higher values mean more distinctively Hindu names.
- **Riot year t**: riots, the instrument and BJP rule are measured in year t; the outcomes are the name indices of people born in t+1.
- **1981 districts**: the 339 districts in 16 states of the riot data (Goyal and van Noort 2025), which Iyer and Shrivastava (2018) also use.
- **TCPD districts**: the districts of the TCPD 2008 (Delim4) constituency-to-district mapping, the unit of the name outcomes.
- **First-stage F**: the Wald F-statistic of the excluded instrument, computed with the stated clustering. With one instrument and one endogenous variable it equals the Kleibergen–Paap F.

## Data

### Name index

The file is `data/0_raw/segregation data 2026/segegation_analysis.csv`, copied on 2026-10-19 from the CEGA Dropbox folder `Riot Names Data/data/0_raw/segregation data 2026` (file dated 2026-10-17). It has 35.1 million rows, one per religion, assembly constituency, birth year and polling booth, with the number of voters and their mean frozen RNI. Births run from 1971 to 1997, and the religions are Hindu and Muslim.

1. Booths are aggregated to constituency, birth year and religion. The constituency index is the voter-weighted mean over booths with a score, weighted by the voters in those booths. Districts take the voter-weighted mean over their constituencies.
2. Between 35% (Assam) and 75% (Uttar Pradesh) of voters in the sample states sit in booths with a score (`rni_frozen_coverage.csv`).
3. Andhra Pradesh constituencies carry post-2014 numbers (1–175). TCPD numbers undivided Andhra Pradesh, so 119 is added. Telangana's constituencies keep their numbers and are coded as Andhra Pradesh, the state they belonged to until 2014.
4. Odisha is excluded. Some Odisha constituencies repeat the same voters several times: one constituency-year has 90,139 births against a state median of 3,327. The index also barely separates the two groups there; the mean RNI is 0.45 for Muslims and 0.34 for Hindus, against roughly 0.8 and 0.15 in Bihar and West Bengal.
5. Coverage gaps in the sample states: Karnataka has 39 of 224 constituencies; Tamil Nadu lacks Madurai, Pudukkottai and Kanniyakumari districts; Assam has 84 of 126 constituencies; Jammu and Kashmir has only 24 constituencies in Jammu region; Gujarat has 160 of 182 and Uttar Pradesh 383 of 403. Chhattisgarh is absent. Assam and Telangana have about 1,000 voters per constituency-year, a third of the typical count.
6. Counts by birth year jump from year to year within constituencies, which points to age heaping in the electoral rolls (ages reported in round numbers). Birth years, and so the timing of the t+1 outcome, are measured with error.

### Riots and the instrument

Riots come from Goyal and van Noort's (2025, *Journal of Conflict Resolution*) district-year panel for 1950–2006, which equals Iyer and Shrivastava's riot data in 1977–2001. The project's district-name mapping (`riots_tcpd_district_mapping.xlsx`) sends Goyal's Kanpur to Nainital in Uttarakhand; the code maps it to Kanpur Nagar instead.

The instrument `fes_iyer` follows Iyer and Shrivastava: 1 if any of the state's three main Hindu festivals, Dushehra or Diwali falls on a Friday (their variable `fesfri`, "Tables 11, 12.do"). It is built from the festival dates in Goyal and van Noort's monthly file (`Riots_DistxMMYY.dta`) and equals Iyer and Shrivastava's `fes` in every row of 1977–2001. It differs from Goyal and van Noort's `fridayfestival` only for Rajasthan in 1955, 1959, 1962, 1982, 1986, 1989 and 2003, when Ramnavami fell on a Friday; their Rajasthan list omits Ramnavami.

### Spatial riot kernel

1. `riotnear_h = exp(-d^2 / (2h^2))`, where d is the distance in km from a district's centroid to the nearest district with a riot that year, and d = 0 if the district had one. The main bandwidth is h = 200 km. This formula reproduces Iyer and Shrivastava's `riotnear200` from their `riotneardist` to within 5e-8.
2. `riotall200` is the sum over the 339 districts of their number of riots, each weighted by `exp(-d^2 / (2 * 200^2))`. `fesnormdist200` is the same weighted sum of the districts' festival dummies.
3. Centroids come from the DataMeet assembly-constituency shapefile (2008 delimitation; CC BY 2.5 IN; downloaded 2026-10-19 from <https://github.com/datameet/maps/tree/master/assembly-constituencies>), dissolved into TCPD districts. Riots are placed at the centroid of the TCPD district that carries the 1981 district's name.
4. Own-district riots (`riot`) are known only for the 285 sample districts on the 1981 list and are 0 elsewhere. The kernel covers every district.

### Controls

Iyer and Shrivastava's controls are BJP rule of the state, Muslim share, urbanisation, literacy, electricity and tap water. The last five come from Goyal and van Noort (from 1971) and Iyer and Shrivastava (tap water, from 1981). Before 1981 they are each district's 1981–1991 linear trend extended backwards, not census values. BJP rule is 0 before 1977. Districts not on the 1981 list take the controls and festival list of the nearest 1981 district in the same state (median distance 51 km).

### Sample

Source: `iyer_panel_by_state.csv`. Voters scored are those born 1971–1996 whose booths have a score.

| State (1990 boundaries) | Districts | On 1981 list | Riot district-years | Muslim voters scored (m) | Hindu voters scored (m) |
|---|---|---|---|---|---|
| Andhra Pradesh (with Telangana) | 23 | 21 | 24 | 1.20 | 8.89 |
| Assam | 30 | 5 | 3 | 0.56 | 0.79 |
| Bihar (with Jharkhand) | 63 | 31 | 47 | 5.08 | 28.58 |
| Gujarat | 31 | 16 | 71 | 0.65 | 8.00 |
| Haryana | 21 | 11 | 2 | 0.49 | 5.61 |
| Jammu and Kashmir | 5 | 3 | 3 | 0.22 | 0.52 |
| Karnataka | 5 | 3 | 13 | 0.26 | 1.80 |
| Kerala | 14 | 11 | 10 | 1.16 | 2.56 |
| Madhya Pradesh | 50 | 38 | 31 | 2.06 | 15.35 |
| Maharashtra | 35 | 26 | 100 | 2.76 | 23.24 |
| Punjab | 22 | 12 | 0 | 0.23 | 2.59 |
| Rajasthan | 33 | 26 | 15 | 1.57 | 13.48 |
| Tamil Nadu | 29 | 12 | 11 | 0.53 | 9.07 |
| Uttar Pradesh (with Uttarakhand) | 89 | 55 | 85 | 10.88 | 43.79 |
| West Bengal | 18 | 15 | 14 | 5.06 | 18.54 |
| Total | 468 | 285 | 429 | 32.72 | 182.81 |

TCPD's district names for Assam are partly constituency or town names, so Assam's 30 units are finer than districts. Sample means (`iyer_panel_summary.csv`): `riot` 0.035, `riotnear200` 0.496 (SD 0.345), `riotall200` 2.29, `fes_iyer` 0.578, Muslim name index 0.671, Hindu name index 0.775.

### Specifications

All columns have district fixed effects; code in `R/02_iyer_models.R`.

1. Own-district riot instrumented by Goyal and van Noort's `fridayfestival`, no other regressors.
2. Own-district riot instrumented by `fes_iyer`, with Iyer and Shrivastava's controls and quadratic time trend.
3. `riotnear200` instrumented by `fes_iyer`, with the quadratic trend.
4. `riotnear200` instrumented by `fes_iyer`, with the controls and trend: Iyer and Shrivastava's main specification (the instrumented regression with controls in their Tables 4 and 5).
5. `riotall200` instrumented by `fes_iyer`, with the controls and trend.
6. `riotall200` instrumented by `fesnormdist200`, with the controls and year fixed effects (their Table 6).

## Results

### Table 1. First stage, riot years 1970–1995

N = 12,161 district-years, 468 districts, 390 state-years. Source: `data/02_output/frozen_rni/06_first_stage_iyer/first_stage_iyer_grid.csv`; the LaTeX rows are the `fs_iyer_*_line.tex` files in the same folder.

| | (1) | (2) | (3) | (4) | (5) | (6) |
|---|---|---|---|---|---|---|
| Endogenous variable | riot | riot | riotnear200 | riotnear200 | riotall200 | riotall200 |
| Instrument | fridayfestival | fes_iyer | fes_iyer | fes_iyer | fes_iyer | fesnormdist200 |
| Coefficient | 0.0104 | 0.0130 | 0.0640 | 0.0652 | 1.000 | 0.0219 |
| F, clustered by district | 11.46 | 17.32 | 417.56 | 435.48 | 344.87 | 81.92 |
| F, clustered by state-year | 4.20 | 7.28 | 4.98 | 5.40 | 11.18 | 2.79 |
| F, two-way (district and state-year) | 4.28 | 7.35 | 5.31 | 5.76 | 11.61 | 2.94 |
| F, clustered by year | 1.96 | 4.23 | 2.21 | 2.37 | 5.40 | 1.04 |

A Friday festival raises `riotnear200` by 0.065 and the kernel-weighted riot count by 1.0, against means of 0.50 and 2.29.

### Why the clustering level matters

The instrument takes one value per state and year. In 6 of the 26 years every state has a Friday festival, and in 6 years no state has one; year fixed effects explain 60% of its variance (`instrument_variation.csv`). Clustering by district treats the districts of a state-year as independent, although they share the instrument value.

The kernel adds to this. One riot raises `riotnear200` in every district within a few hundred kilometres, so first-stage errors are correlated across districts in the same state-year. Abadie, Athey, Imbens and Wooldridge (2023, *Quarterly Journal of Economics*) recommend clustering at the level at which the instrument is assigned, here the state-year. Year clustering (26 clusters) also allows for the common national component. State clustering (15 clusters) is too coarse for cluster-robust inference and is reported only in the CSV.

### Table 2. The same diagnostics on Iyer and Shrivastava's data

Source: `data/02_output/06_first_stage_iyer/iyer_benchmark.csv`. Rows 1–2 reproduce their Table 5 first stage from `dataset_robustness.dta`.

| Specification | N | F, district | F, state-year | F, two-way | F, year |
|---|---|---|---|---|---|
| Table 5 col. 2: riotnear200, election years | 1,333 | 164.6 | 12.8 | 16.9 | 12.4 |
| Table 5 col. 4: riot, election years | 1,333 | 19.4 | 9.9 | 11.8 | 6.5 |
| riotnear200, all years 1977–1995 | 6,441 | 374.8 | 11.4 | 12.5 | 7.1 |
| riot, all years 1977–1995 | 6,441 | 29.2 | 12.3 | 12.7 | 7.9 |

Their first stage shows the same drop from district to state-year clustering.

### Table 3. Which years and states carry the first stage

Goyal and van Noort's 339-district panel, all 16 states, `riot ~ fes_iyer + quadratic trend + district FE`. Source: `data/02_output/06_first_stage_iyer/goyal_panel_first_stage.csv`.

| Riot years | States dropped | F, district | F, state-year | F, two-way |
|---|---|---|---|---|
| 1950–1995 | none | 20.0 | 8.9 | 8.4 |
| 1970–1995 | none | 23.4 | 9.0 | 9.1 |
| 1977–1995 | none | 29.2 | 12.3 | 12.7 |
| 1970–1976 | none | 0.5 | 0.2 | 0.3 |
| 1950–2006 | none | 32.4 | 11.6 | 11.6 |
| 1970–1995 | Maharashtra | 13.5 | 5.8 | 5.7 |

Riot years 1970–1976 have no first-stage relation, so they add observations but no identifying variation. Maharashtra is the state whose removal lowers the 1970–1995 F the most.

### Table 4. Variants of the main specification

F-statistics clustered by district and by state-year. Source: `first_stage_iyer_grid.csv` (frozen-RNI folder).

| Variant of column 4 | 1970–95, district | 1970–95, state-year | 1977–95, district | 1977–95, state-year |
|---|---|---|---|---|
| Main specification | 435.5 | 5.40 | 609.3 | 9.64 |
| Bandwidth 100 km | 190.8 | 7.38 | 243.4 | 9.97 |
| Bandwidth 150 km | 329.4 | 6.40 | 430.7 | 10.09 |
| Bandwidth 250 km | 438.3 | 4.61 | 727.0 | 9.23 |
| Bandwidth 300 km | 379.3 | 3.97 | 786.9 | 8.97 |
| Goyal and van Noort's fridayfestival as instrument | 318.4 | 4.54 | 489.5 | 8.43 |
| Districts on the 1981 list only | 258.5 | 5.16 | 389.1 | 10.11 |
| Year fixed effects instead of trend | 3.18 | 0.17 | 0.31 | 0.02 |
| Weighted by voters scored | 560.7 | 5.78 | 601.7 | 9.62 |
| riotall200 (column 5) | 344.9 | 11.18 | 404.7 | 10.80 |
| riotall200, weighted by voters scored | 219.3 | 12.24 | 269.0 | 10.48 |

Under state-year clustering, the kernel-weighted riot count and narrower bandwidths give the strongest first stage. Year fixed effects remove the variation the instrument has. The two-way F of the weighted `riotall200` variant (12.52 and 11.04 in the CSV) uses `fixest`'s adjustment of a covariance matrix that was not positive semi-definite.

### Table 5. Second stage, riot years 1970–1995

2SLS coefficient, with the standard error clustered by district in parentheses and by state-year in brackets. Source: `data/02_output/frozen_rni/07_table_iyer_muslim/` and `07_table_iyer_hindu/` (`iyer_iv_*_line.tex`; OLS and reduced-form rows are in the same folders).

| Outcome (births in t+1) | (1) | (2) | (3) | (4) | (5) | (6) |
|---|---|---|---|---|---|---|
| Muslim name index | 0.0766 | 0.1167 | 0.0123 | 0.0233 | 0.0015 | 0.0038 |
| | (0.0630) | (0.0516) | (0.0090) | (0.0085) | (0.0006) | (0.0026) |
| | [0.2148] | [0.1611] | [0.0337] | [0.0309] | [0.0021] | [0.0072] |
| Hindu name index | 0.0829 | 0.1075 | 0.0283 | 0.0215 | 0.0014 | 0.0026 |
| | (0.0331) | (0.0301) | (0.0038) | (0.0033) | (0.0002) | (0.0010) |
| | [0.1437] | [0.0947] | [0.0227] | [0.0188] | [0.0012] | [0.0040] |

Columns differ in the scale of the endogenous variable. In column 4, a district that goes from no riot nearby (`riotnear200` = 0) to a riot of its own (`riotnear200` = 1) has a Muslim name index 0.023 higher and a Hindu name index 0.021 higher in the next birth cohort. The sample means of the two indices are 0.671 and 0.775.

### Table 6. Inference that remains valid with a weak instrument

With a weak first stage, the usual 2SLS t-test is unreliable. The Anderson–Rubin set is valid at any instrument strength (Andrews, Stock and Sun 2019, *Annual Review of Economics*); with one instrument, its test of a zero effect is the reduced-form t-test. Main specification (column 4); source: `anderson_rubin_iyer.csv` (frozen-RNI folder), which also covers columns 2 and 5 and two-way clustering.

| Riot years | Outcome | 2SLS | p, state-year SE | AR 95% set, district | AR 95% set, state-year | AR p of zero effect, district | AR p of zero effect, state-year |
|---|---|---|---|---|---|---|---|
| 1970–1995 | Muslim | 0.0233 | 0.452 | 0.007 to 0.040 | -0.059 to 0.183 | 0.007 | 0.444 |
| 1970–1995 | Hindu | 0.0215 | 0.254 | 0.015 to 0.028 | -0.013 to 0.159 | <0.001 | 0.197 |
| 1977–1995 | Muslim | 0.0099 | 0.657 | -0.003 to 0.023 | -0.051 to 0.063 | 0.130 | 0.664 |
| 1977–1995 | Hindu | -0.0027 | 0.793 | -0.007 to 0.002 | -0.035 to 0.019 | 0.240 | 0.789 |

The reduced form, and with it the Anderson–Rubin test, does not depend on which endogenous variable is used, so columns 2, 4 and 5 give the same p-values for a zero effect. The positive effects in 1970–1995 rest on district clustering; they are not distinguishable from zero under state-year clustering, and the 1977–1995 effects are not distinguishable from zero under either.

### Check of the rebuilt kernel

Iyer and Shrivastava's 339 districts in 1977–2001 (8,475 district-years), with the kernel rebuilt from the constituency-map centroids and Goyal and van Noort's riots. Source: `data/02_output/08_kernel_validation/` (CSV and scatter plot).

| Statistic | Value |
|---|---|
| Correlation of distance to nearest riot with Iyer and Shrivastava's | 0.975 |
| Correlation of riotnear200 with theirs | 0.975 |
| Median absolute distance error | 16 km |
| 90th / 95th percentile of the distance error | 52 km / 66 km |
| Mean absolute difference in riotnear200 | 0.046 |
| fes_iyer equal to their fes (1977–2001) | 100% of rows |

The largest distance errors occur in years with few riots, such as 1994 (7 riots), when the nearest riot is 400 to 1,500 km away and the kernel is near zero under either set of coordinates. Iyer and Shrivastava's coordinates are not in their files.

## Caveats

1. The kernel estimates the effect of exposure to nearby riots, not of a riot in one's own district. The exclusion restriction must hold for the whole area within a few hundred kilometres.
2. Choosing a specification because its F-statistic is large biases inference after the choice. All variants tried are reported here.
3. The outcomes rest on names that existed before 1970. Depending on the state, a quarter to two-thirds of voters are in booth cells with no score and drop out.
4. Birth years are heaped, so riots in year t are compared with a cohort that partly includes people born in neighbouring years.
5. The kernel uses centroids of 2008 districts and riots in the 16 states of the riot data only; riots elsewhere, such as in Delhi, are not counted.
6. Controls before 1981 are linear trends, not census values. The 2SLS standard errors use `fixest`'s default small-sample corrections; Stata's `xtivreg2` uses none, so numbers computed there can differ slightly.

## Recommendations

1. Report the first-stage F clustered by state-year (or two-way) next to the district-clustered F, and base inference on the Anderson–Rubin sets.
2. Consider `riotall200` (column 5) as the main endogenous variable. It is the only one with a state-year-clustered F above 10 in 1970–1995 (11.2; 12.2 weighted by voters scored).
3. Report riot years 1977–1995 as a robustness check. The main specification's state-year F rises to 9.6 there, but the second-stage effects are not significant.
4. Fill the coverage gaps upstream: Odisha's duplicated records, Karnataka, Madurai, Pudukkottai and Kanniyakumari, Assam, the Kashmir valley and Chhattisgarh.

## Files

- Code: `R/01_rni_read.R` (`get_rni_frozen_annual_raw()` and the cleaning functions), `R/01_festival.R`, `R/01_spatial.R`, `R/02_iyer_data.R`, `R/02_iyer_models.R`, `R/02_iyer_benchmarks.R`. Targets with the suffix `_frozen` in `_targets.R` (for example `rni_riots_iyer_frozen`).
- Run: `Rscript --no-save --no-restore -e "targets::tar_make()"` from the project root.
- Outputs for the frozen name index: `data/02_output/frozen_rni/` (`rni_frozen_coverage.csv`; `06_first_stage_iyer/` with the first-stage grid, LaTeX rows, Anderson–Rubin sets, instrument variation and sample summaries; `07_table_iyer_muslim/` and `07_table_iyer_hindu/` with OLS, reduced-form and 2SLS rows).
- Outputs that do not depend on the name data: `data/02_output/06_first_stage_iyer/iyer_benchmark.csv` and `goyal_panel_first_stage.csv`; `data/02_output/08_kernel_validation/`.
