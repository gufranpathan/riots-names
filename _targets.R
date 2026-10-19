library(targets)
library(dplyr)
library(stringr)
library(tidyr)
library(tarchetypes)
library(ggplot2)
library(arrow)
library(haven)
library(readxl)
library(scales)
library(patchwork)
library(sf)

source("R/00_utils.R")

source("R/01_riots_cleaning.R")
source("R/01_rni_read.R")
source("R/01_festival.R")
source("R/01_spatial.R")
source("R/02_models.R")
source("R/02_iyer_data.R")
source("R/02_iyer_models.R")
source("R/02_iyer_benchmarks.R")
source("R/03_descriptive_table.R")
source("R/04_descriptive_plots.R")


tar_plan(
  
  # Paths ----
  tar_target(riots_raw_path,"data/0_raw/01-riots/hm-riots-replication/data/riots/varshney-wilkson-mitra-ray.csv",format='file'),
  tar_target(riots_allie_path,"data/0_raw/01-riots/hm-riots-replication/data/final-data/dta.rds",format='file'),
  tar_target(riots_goyal_path,"data/0_raw/01-riots/sj-zip-2-jcr-10.1177_00220027251383563/Final ethnic riots data.dta",format='file'),
  tar_target(rni_parquet_paths,get_rni_parquet_paths(),format='file'),
  tar_target(rni_annual_paths,get_rni_annual_paths(),format='file'),
  tar_target(ac_delim_path,"data/0_raw/12-delim4/TCPD_AC_PC_Mapping_Delim4.csv",format='file'),
  tar_target(district_corrections_path,"data/0_raw/01-riots/riots_tcpd_district_mapping.xlsx",format='file'),
  tar_target(riots_monthly_path,"data/0_raw/01-riots/sj-zip-2-jcr-10.1177_00220027251383563/Riots_DistxMMYY.dta",format='file'),
  tar_target(iyer_robustness_path,"data/0_raw/01-riots/iyer/Replication/dataset_robustness.dta",format='file'),
  tar_target(ac_shapefile_paths,list.files("data/0_raw/13-ac-shapefile",pattern="^India_AC\\.(shp|dbf|shx|prj)$",full.names=TRUE),format='file'),
  tar_target(rni_frozen_path,"data/0_raw/segregation data 2026/segegation_analysis.csv",format='file'),

  
  
  # Read Data ----
  riots_raw = read.csv(riots_raw_path) %>% rename_with(tolower),
  ac_delim = read.csv(ac_delim_path) %>% 
    filter(DelimID==4) %>% 
    mutate(district=str_remove_all(str_to_lower(District_Name)," "),
           state=str_to_lower(str_remove_all(State_Name,"_|\\&"))),
  riots_allie = readRDS(riots_allie_path),
  rni_raw = get_rni_raw(rni_parquet_paths),
  rni_annual_raw = get_rni_annual_raw(rni_annual_paths),
  riots_goyal_raw = read_dta(riots_goyal_path),
  district_corrections = read_excel(district_corrections_path),
  riots_monthly_raw = read_dta(riots_monthly_path),
  iyer_robustness_raw = read_dta(iyer_robustness_path),
  ac_shapes = get_ac_shapes(ac_shapefile_paths),
  rni_frozen_annual_raw = get_rni_frozen_annual_raw(rni_frozen_path),

  # Clean / Process Data ----
  riots_annual = get_riots_annual(riots_raw),
  riots_location = get_riots_location(riots_annual),
  rni_clean = get_rni_clean(rni_annual_raw, ac_delim),
  rni_ac = get_rni_ac(rni_clean),
  rni_district = get_rni_district(rni_clean),
  riots_goyal_clean = get_riots_goyal_clean(riots_goyal_raw, district_corrections),
  friday_festival = get_friday_festival(riots_goyal_clean),
  rni_riots = get_rni_riots(rni_district,riots_goyal_clean,friday_festival),
  iv_models = get_iv_models(rni_riots),
  tar_target(table1_latex_path,get_table1_latex(iv_models),format='file'),
  tar_target(summary_stats_table_path,get_summary_stats_table(rni_riots),format='file'),
  tar_target(first_stage_table_path,get_first_stage_table(iv_models),format='file'),
  
  tar_target(rni_densities_plot_path,get_rni_densities_plot(iv_models, rni_riots),format='file'),
  tar_target(time_trends_by_riot_path,get_time_trends_by_riot(rni_riots),format='file'),
  
  tar_target(muslim_model_table_path,get_model_tables(rni_riots,religion = 'muslim'),format='file'),
  tar_target(hindu_model_table_path,get_model_tables(rni_riots,religion = 'hindu'),format='file'),
  tar_target(riot_friday_festival_trend_path,get_riot_friday_festival_trend(rni_riots),format='file'),

  # Frozen RNI (names scored on births before 1970; births 1971-1997) ----
  rni_frozen_clean = get_rni_frozen_clean(rni_frozen_annual_raw, ac_delim),
  rni_frozen_district = get_rni_frozen_district(rni_frozen_clean),
  tar_target(rni_frozen_coverage_path,get_rni_frozen_coverage(rni_frozen_annual_raw, rni_frozen_clean),format='file'),

  # Iyer & Shrivastava (2018) style first stage, riot years 1970-1995 ----
  # see docs/first_stage_iyer_frozen_rni_20261019.md
  # Shared by both RNI versions
  festival_iyer = get_festival_iyer(riots_monthly_raw),
  district_centroids = get_district_centroids(ac_shapes, ac_delim),
  district_parents = get_district_parents(riots_goyal_clean, district_centroids),
  riot_kernel = get_riot_kernel(district_parents, riots_goyal_clean, festival_iyer, district_centroids),
  district_controls = get_district_controls(riots_goyal_clean, iyer_robustness_raw),
  tar_target(kernel_validation_path,get_kernel_validation(riots_goyal_clean, district_centroids, iyer_robustness_raw, festival_iyer),format='file'),
  tar_target(iyer_benchmark_path,get_iyer_benchmark(iyer_robustness_raw),format='file'),
  tar_target(goyal_panel_first_stage_path,get_goyal_panel_first_stage(riots_goyal_clean, festival_iyer, district_centroids),format='file'),

  # One branch per RNI version; target names get the suffix _frozen (main analysis, outputs in
  # data/02_output/frozen_rni/) or _annual (rni_annual files, outputs in data/02_output/)
  tar_map(
    values = tibble::tibble(rni = c("frozen", "annual"),
                            rni_district_input = rlang::syms(c("rni_frozen_district", "rni_district")),
                            output_root = c("data/02_output/frozen_rni/", "data/02_output/")),
    names = "rni",
    tar_target(rni_riots_iyer,get_rni_riots_iyer(rni_district_input, district_parents, riots_goyal_clean, festival_iyer, riot_kernel, district_controls)),
    tar_target(iv_models_iyer,get_iv_models_iyer(rni_riots_iyer)),
    tar_target(first_stage_iyer_grid_path,get_first_stage_iyer_grid(rni_riots_iyer, output_root),format='file'),
    tar_target(first_stage_iyer_table_path,get_first_stage_iyer_table(rni_riots_iyer, output_root),format='file'),
    tar_target(muslim_iyer_table_path,get_iyer_model_tables(iv_models_iyer, rni_riots_iyer, religion = 'muslim', output_root = output_root),format='file'),
    tar_target(hindu_iyer_table_path,get_iyer_model_tables(iv_models_iyer, rni_riots_iyer, religion = 'hindu', output_root = output_root),format='file'),
    tar_target(anderson_rubin_iyer_path,get_anderson_rubin_iyer(rni_riots_iyer, output_root),format='file'),
    tar_target(instrument_variation_path,get_instrument_variation(rni_riots_iyer, output_root),format='file'),
    tar_target(iyer_panel_summary_path,get_iyer_panel_summary(rni_riots_iyer, output_root),format='file')
  ),

  

  
  # event_study_data = get_event_study_data(rni_riots),
  # event_study_summary = get_event_study_summary(event_study_data)
  
  
)