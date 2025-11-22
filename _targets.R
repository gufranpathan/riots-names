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

source("R/00_utils.R")

source("R/01_riots_cleaning.R")
source("R/01_rni_read.R")
source("R/02_models.R")
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
  
  

  
  # event_study_data = get_event_study_data(rni_riots),
  # event_study_summary = get_event_study_summary(event_study_data)
  
  
)