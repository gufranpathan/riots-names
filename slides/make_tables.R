# Write the deck's tables into tables/ next to this script, as LaTeX tabulars laid
# out like the tables in the paper (docs/main.tex). riots_names_results.qmd wraps each
# in an econtable environment (tables_preamble.tex) with its notes. Numbers come from
# the targets pipeline for the frozen name index (riot years 1970-1995):
# rni_riots_iyer_frozen, iv_models_iyer_frozen and riots_goyal_clean. Run from the
# project root (renv) after targets::tar_make():
#   Rscript --no-save --no-restore slides/make_tables.R
#
# The main results table uses one specification, riot exposure (riotnear200) with Iyer
# and Shrivastava's controls and quadratic trend. The appendix tables add own-district
# riots and the kernel-weighted riot count.

suppressMessages({
  library(targets)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(fixest)
})
source("R/02_iyer_models.R") # iyer_specs, iyer_formula()

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
out_dir <- file.path(if (length(script) == 1) dirname(script) else "slides", "tables")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

panel <- tar_read(rni_riots_iyer_frozen)
models <- tar_read(iv_models_iyer_frozen)
riot_counts <- tar_read(riots_goyal_clean) %>%
  haven::zap_labels() %>%
  select(dist, year, KILLED, INJURED)

main_spec <- "4" # riot exposure, Iyer and Shrivastava's main specification
appendix_specs <- iyer_specs %>% filter(spec %in% c("1", "2", "4", "5"))
riot_measure <- c(riot = "Riot", riotnear200 = "Exposure", riotall200 = "Count")

# ---- LaTeX helpers ----
num <- function(x, digits) {
  out <- formatC(x, format = "f", digits = digits, big.mark = ",")
  str_replace(out, "^-", "−")
}
# whole numbers without decimals (counts, minima, maxima)
num_auto <- function(x, digits) ifelse(abs(x - round(x)) < 1e-9, num(x, 0), num(x, digits))
stars <- function(p) case_when(p < 0.01 ~ "\\sym{***}", p < 0.05 ~ "\\sym{**}", p < 0.1 ~ "\\sym{*}", TRUE ~ "")
tex_row <- function(...) paste0(paste(c(...), collapse = " & "), " \\\\")
span_row <- function(label, n_cols, style = "\\textbf") paste0("\\multicolumn{", n_cols, "}{l}{", style, "{", label, "}} \\\\")
yes_no <- function(x) ifelse(x, "Yes", "No")
write_tabular <- function(lines, name, columns) {
  path <- file.path(out_dir, paste0(name, ".tex"))
  writeLines(c("% Written by slides/make_tables.R from the targets pipeline; do not edit by hand.",
               paste0("\\begin{tabular}{", columns, "}"), lines, "\\end{tabular}"),
             path, useBytes = TRUE)
  path
}
wide_columns <- function(n, width) paste0("l*{", n, "}{>{\\centering\\arraybackslash}p{", width, "}}")

# ---- Summary statistics (the paper's Table 1) ----
# Own-district riots exist only for districts on the 1981 list; missing deaths and
# injuries count as 0, as in the paper
on_list <- panel %>%
  filter(matched) %>%
  left_join(riot_counts, by = c("dist", "year")) %>%
  mutate(KILLED = replace_na(KILLED, 0), INJURED = replace_na(INJURED, 0))

describe <- function(x, label, digits) {
  tex_row(label, num(length(x), 0), num(mean(x), digits), num(sd(x), digits),
          num_auto(min(x), digits), num_auto(max(x), digits), num_auto(median(x), digits))
}
summary_stats <- c(
  "\\toprule", "\\toprule",
  "& \\multicolumn{6}{c}{\\textbf{Panel A: Full Sample}} \\\\",
  "\\cmidrule(lr){2-7}",
  tex_row("Variable", "N", "Mean", "SD", "Min", "Max", "Median"),
  "\\midrule",
  span_row("Outcome Variables", 7, "\\textit"),
  describe(panel$rni_Muslim_lead, "Muslim Name Index (t+1)", 3),
  describe(panel$rni_Hindu_lead, "Hindu Name Index (t+1)", 3),
  describe(panel$people_Muslim_lead, "Number of Muslims (scored)", 0),
  describe(panel$people_Hindu_lead, "Number of Hindus (scored)", 0),
  "\\addlinespace",
  span_row("Riots (Districts on the 1981 List)", 7, "\\textit"),
  describe(on_list$riot, "Riot occurrence", 3),
  describe(on_list$nriot, "Number of riots", 2),
  describe(on_list$KILLED, "Deaths in riots", 2),
  describe(on_list$INJURED, "Injuries in riots", 2),
  "\\addlinespace",
  span_row("Riot Exposure \\& Instrument", 7, "\\textit"),
  describe(panel$riotnear200, "Riot exposure", 3),
  describe(panel$fes_iyer, "Friday Festival", 3),
  "\\bottomrule", "\\bottomrule"
)
write_tabular(summary_stats, "summary_stats", "l*{6}{c}")

compare <- function(var, label, digits) {
  with_riot <- on_list[[var]][on_list$riot == 1]
  without <- on_list[[var]][on_list$riot == 0]
  fit <- feols(as.formula(paste(var, "~ riot")), data = on_list, cluster = ~district_id, notes = FALSE)
  tex_row(label, num(mean(with_riot), digits), num(sd(with_riot), digits),
          num(mean(without), digits), num(sd(without), digits),
          paste0(num(coef(fit)["riot"], digits), stars(pvalue(fit)["riot"])),
          num(pvalue(fit)["riot"], 3))
}
riot_comparison <- c(
  "\\toprule", "\\toprule",
  "& \\multicolumn{6}{c}{\\textbf{Panel B: Riot vs. Non-Riot District-Years}} \\\\",
  "\\cmidrule(lr){2-7}",
  "Variable & \\multicolumn{2}{c}{Riot=1} & \\multicolumn{2}{c}{Riot=0} & Difference & P-value \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  tex_row("", "Mean", "SD", "Mean", "SD", "", ""),
  "\\midrule",
  span_row("Outcome Variables", 7, "\\textit"),
  compare("rni_Muslim_lead", "Muslim Name Index (t+1)", 3),
  compare("rni_Hindu_lead", "Hindu Name Index (t+1)", 3),
  "\\addlinespace",
  span_row("Instrument", 7, "\\textit"),
  compare("fes_iyer", "Friday Festival", 3),
  "\\addlinespace",
  tex_row("Observations", num(sum(on_list$riot == 1), 0), "", num(sum(on_list$riot == 0), 0), "", "", ""),
  "\\bottomrule", "\\bottomrule"
)
write_tabular(riot_comparison, "riot_comparison", "l*{6}{c}")

# ---- Estimates ----
first_stage <- lapply(seq_len(nrow(appendix_specs)), function(i) {
  spec_row <- appendix_specs[i, ]
  fit <- feols(iyer_formula(spec_row, NULL, "fs"), data = panel, cluster = ~district_id, notes = FALSE)
  fit_state_year <- summary(fit, cluster = ~state_year)
  z <- spec_row$instrument
  tibble(spec = spec_row$spec, coef = unname(coef(fit)[z]), se = unname(se(fit)[z]), p = unname(pvalue(fit)[z]),
         se_state_year = unname(se(fit_state_year)[z]), n = nobs(fit), r2 = unname(r2(fit, "r2"))) %>%
    mutate(F_district = (coef / se)^2, F_state_year = (coef / se_state_year)^2)
}) %>% bind_rows()

# Same numbers as the pipeline's first-stage grid (docs/first_stage_iyer_frozen_rni_20261019.md)
grid <- read.csv("data/02_output/frozen_rni/06_first_stage_iyer/first_stage_iyer_grid.csv") %>%
  filter(window == "1970-1995", spec %in% first_stage$spec)
grid <- grid[match(first_stage$spec, grid$spec), ]
stopifnot(isTRUE(all.equal(first_stage$F_district, grid$F_district)),
          isTRUE(all.equal(first_stage$F_state_year, grid$F_state_year)))

estimate <- function(model, variable, cluster = NULL) {
  if (!is.null(cluster)) model <- summary(model, cluster = list(panel[[cluster]][obs(model)]))
  c(coef = unname(coef(model)[variable]), se = unname(se(model)[variable]), p = unname(pvalue(model)[variable]))
}
effects <- function(outcome, spec_row) {
  m <- models[[outcome]][[spec_row$spec]]
  iv_var <- paste0("fit_", spec_row$endog)
  list(ols = estimate(m$ols, spec_row$endog),
       rf = estimate(m$rf, spec_row$instrument),
       rf_sy = estimate(m$rf, spec_row$instrument, "state_year"),
       iv = estimate(m$iv, iv_var),
       iv_sy = estimate(m$iv, iv_var, "state_year"),
       n = nobs(m$iv))
}

# four decimals, or five where a standard error would round to zero (the riot count's
# coefficients are small because the count runs to about 40)
digits <- function(r, type) if (round(r[[type]][["se"]], 4) == 0) 5 else 4
coef_cells <- function(cols, type) sapply(cols, function(r) paste0(num(r[[type]][["coef"]], digits(r, type)), stars(r[[type]][["p"]])))
se_cells <- function(cols, type, open = "(", close = ")", digits_from = type) {
  sapply(cols, function(r) paste0(open, num(r[[type]][["se"]], digits(r, digits_from)), close))
}
# Standard errors clustered by district in parentheses, then by state-year in brackets
# on the next line
both_se_rows <- function(cols, type, type_state_year) {
  c(tex_row("", se_cells(cols, type)),
    tex_row("", se_cells(cols, type_state_year, "[", "]", digits_from = type)))
}
fs_cols <- function(fs) lapply(seq_len(nrow(fs)), function(i) list(fs = c(coef = fs$coef[i], se = fs$se[i], p = fs$p[i]),
                                                                  fs_sy = c(coef = fs$coef[i], se = fs$se_state_year[i], p = fs$p[i])))

# state_year = FALSE: standard errors clustered by district only (the main slide)
estimate_panels <- function(cols, n_cols, endog_label, state_year = TRUE) {
  se_rows <- function(type) {
    if (state_year) both_se_rows(cols, type, paste0(type, "_sy")) else tex_row("", se_cells(cols, type))
  }
  c(span_row("Panel A: OLS Estimates", n_cols),
    tex_row(endog_label, coef_cells(cols, "ols")),
    tex_row("", se_cells(cols, "ols")),
    "\\addlinespace",
    span_row("Panel B: Reduced Form Estimates", n_cols),
    tex_row("Friday Festival", coef_cells(cols, "rf")),
    se_rows("rf"),
    "\\addlinespace",
    span_row("Panel C: IV Estimates", n_cols),
    tex_row(paste(endog_label, "(instrumented)"), coef_cells(cols, "iv")),
    se_rows("iv"))
}
controls <- function(specs) yes_no(str_detect(specs$exog, "bjprule"))
trend <- function(specs) yes_no(str_detect(specs$exog, "tsq"))
district_fe <- function(specs) yes_no(str_detect(specs$fe, "district_id"))
festival_coding <- function(specs) ifelse(specs$instrument == "fridayfestival", "Goyal", "Iyer")

# ---- Main specification: riot exposure ----
main_row <- appendix_specs %>% filter(spec == main_spec)
fs_main <- first_stage %>% filter(spec == main_spec)

# ---- Effects on both name indices (the paper's Tables 3 and 4): riot exposure ----
main_cols <- list(effects("rni_Muslim_lead", main_row), effects("rni_Hindu_lead", main_row))
effects_table <- c(
  "\\toprule",
  "& \\textbf{Muslim Name Index (t+1)} & \\textbf{Hindu Name Index (t+1)} \\\\",
  "\\cmidrule(lr){2-2} \\cmidrule(lr){3-3}",
  tex_row("", "(1)", "(2)"),
  "\\midrule",
  # clustered by district only; the appendix tables add state-year clusters
  estimate_panels(main_cols, 3, "Riot exposure", state_year = FALSE),
  "\\addlinespace",
  tex_row("First-stage F-statistic", rep(num(fs_main$F_district, 2), 2)),
  "\\midrule",
  tex_row("Observations", sapply(main_cols, function(r) num(r$n, 0))),
  "\\midrule",
  tex_row("Controls", rep(controls(main_row), 2)),
  tex_row("Quadratic Year Trend", rep(trend(main_row), 2)),
  tex_row("District FE", rep(district_fe(main_row), 2)),
  "\\bottomrule"
)
write_tabular(effects_table, "effects", wide_columns(2, "40mm"))

# ---- Appendix: four specifications ----
measure_row <- tex_row("Riot Measure", riot_measure[appendix_specs$endog])
app_fs_cols <- fs_cols(first_stage)
app_first_stage <- c(
  "\\toprule",
  "& \\multicolumn{4}{c}{\\textbf{Dependent Variable: Riot Measure}} \\\\",
  "\\cmidrule(lr){2-5}",
  tex_row("", "(1)", "(2)", "(3)", "(4)"),
  measure_row,
  "\\midrule",
  tex_row("Festival on Friday", coef_cells(app_fs_cols, "fs")),
  both_se_rows(app_fs_cols, "fs", "fs_sy"),
  "\\addlinespace",
  tex_row("First-stage F, district clusters", num(first_stage$F_district, 2)),
  tex_row("First-stage F, state-year clusters", num(first_stage$F_state_year, 2)),
  "\\midrule",
  tex_row("Observations", num(first_stage$n, 0)),
  tex_row("R-squared", num(first_stage$r2, 3)),
  "\\midrule",
  tex_row("Festival Coding", festival_coding(appendix_specs)),
  tex_row("Controls", controls(appendix_specs)),
  tex_row("Quadratic Year Trend", trend(appendix_specs)),
  tex_row("District FE", district_fe(appendix_specs)),
  "\\bottomrule"
)
write_tabular(app_first_stage, "app_first_stage", "l*{4}{c}")

app_effects <- function(outcome, outcome_label) {
  cols <- lapply(seq_len(nrow(appendix_specs)), function(i) effects(outcome, appendix_specs[i, ]))
  c("\\toprule",
    paste0("& \\multicolumn{4}{c}{\\textbf{Outcome: ", outcome_label, " (t+1)}} \\\\"),
    "\\cmidrule(lr){2-5}",
    tex_row("", "(1)", "(2)", "(3)", "(4)"),
    measure_row,
    "\\midrule",
    estimate_panels(cols, 5, "Riot measure"),
    "\\addlinespace",
    tex_row("First-stage F, district clusters", num(first_stage$F_district, 2)),
    tex_row("First-stage F, state-year clusters", num(first_stage$F_state_year, 2)),
    "\\midrule",
    tex_row("Observations", sapply(cols, function(r) num(r$n, 0))),
    "\\midrule",
    tex_row("Festival Coding", festival_coding(appendix_specs)),
    # one row: every column has both or neither
    tex_row("Controls and Quadratic Trend", controls(appendix_specs)),
    tex_row("District FE", district_fe(appendix_specs)),
    "\\bottomrule")
}
stopifnot(identical(controls(appendix_specs), trend(appendix_specs)))
write_tabular(app_effects("rni_Muslim_lead", "Muslim Name Index"), "app_effects_muslim", wide_columns(4, "22mm"))
write_tabular(app_effects("rni_Hindu_lead", "Hindu Name Index"), "app_effects_hindu", wide_columns(4, "22mm"))

# ---- Appendix: Anderson-Rubin tests of a zero IV effect, by specification ----
# From the pipeline (get_anderson_rubin_iyer): the AR p-value of a zero effect and the
# AR 95% set, with standard errors clustered by district and by state-year
anderson_rubin <- read.csv("data/02_output/frozen_rni/06_first_stage_iyer/anderson_rubin_iyer.csv") %>%
  filter(window == "1970-1995")
ar_value <- function(outcome, cluster, field) {
  sapply(appendix_specs$spec, function(s) {
    row <- anderson_rubin %>% filter(outcome == !!outcome, cluster == !!cluster, spec == as.integer(s))
    stopifnot(nrow(row) == 1)
    row[[field]]
  })
}
ar_p_cells <- function(outcome, cluster) {
  p <- ar_value(outcome, cluster, "ar_p_beta0")
  ifelse(p < 0.0005, "<0.001", num(p, 3))
}
ar_set_cells <- function(outcome, cluster) {
  type <- ar_value(outcome, cluster, "ar_set")
  lower <- num(ar_value(outcome, cluster, "ar_lower"), 4)
  upper <- num(ar_value(outcome, cluster, "ar_upper"), 4)
  case_when(type == "interval" ~ paste0("[", lower, ", ", upper, "]"),
            type == "whole real line" ~ "$(-\\infty,\\infty)$",
            TRUE ~ paste0("$(-\\infty$, ", lower, "$]\\cup[$", upper, "$,\\infty)$"))
}
ar_panel <- function(outcome, label) {
  # the AR file's 2SLS estimates are the effect tables' Panel C estimates
  iv <- sapply(seq_len(nrow(appendix_specs)), function(i) effects(outcome, appendix_specs[i, ])$iv[["coef"]])
  stopifnot(isTRUE(all.equal(unname(ar_value(outcome, "district", "tsls")), iv)))
  c(span_row(label, 5),
    tex_row("IV estimate", num(iv, 4)),
    tex_row("AR p-value, district clusters", ar_p_cells(outcome, "district")),
    tex_row("AR p-value, state-year clusters", ar_p_cells(outcome, "state_year")),
    tex_row("AR 95\\% set, district clusters", ar_set_cells(outcome, "district")),
    tex_row("AR 95\\% set, state-year clusters", ar_set_cells(outcome, "state_year")))
}
app_anderson_rubin <- c(
  "\\toprule",
  "& \\multicolumn{4}{c}{\\textbf{Anderson--Rubin Tests of a Zero IV Effect}} \\\\",
  "\\cmidrule(lr){2-5}",
  tex_row("", "(1)", "(2)", "(3)", "(4)"),
  measure_row,
  "\\midrule",
  ar_panel("rni_Muslim_lead", "Panel A: Muslim Name Index (t+1)"),
  "\\addlinespace",
  ar_panel("rni_Hindu_lead", "Panel B: Hindu Name Index (t+1)"),
  "\\bottomrule"
)
write_tabular(app_anderson_rubin, "app_anderson_rubin", "l*{4}{c}")

# tables from earlier layouts of the deck
unlink(file.path(out_dir, c("effects_muslim.tex", "effects_hindu.tex", "first_stage.tex")))
cat(list.files(out_dir, full.names = TRUE), sep = "\n")
