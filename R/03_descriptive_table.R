# ============================================================================
# Summary Statistics Table Generator - Targets-Compatible Version
# ============================================================================

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

format_num <- function(x, digits = 3) {
  sprintf(paste0("%.", digits, "f"), x)
}

format_comma <- function(x) {
  formatC(x, format = "d", big.mark = ",")
}

format_numbers <- function(x,digits) {
  ifelse(x %% 1 == 0,
         comma(x),           # Add commas to integers
         number(x, accuracy = 1/10^digits))  # 3 decimal places
}


add_stars <- function(p_value) {
  if (is.na(p_value)) return("")
  if (p_value < 0.01) return("***")
  if (p_value < 0.05) return("**")
  if (p_value < 0.1) return("*")
  return("")
}

# Function to generate a single Panel A row
generate_panelA_row <- function(data, varname, label, digits = 3) {
  n <- sum(!is.na(data[[varname]]))
  mean_val <- mean(data[[varname]], na.rm = TRUE)
  sd_val <- sd(data[[varname]], na.rm = TRUE)
  min_val <- min(data[[varname]], na.rm = TRUE)
  max_val <- max(data[[varname]], na.rm = TRUE)
  median_val <- median(data[[varname]], na.rm = TRUE)
  
  sprintf("%s & %s & %s & %s & %s & %s & %s \\\\",
          label,
          format_numbers(n),
          format_numbers(mean_val, digits),
          format_numbers(sd_val, digits),
          format_numbers(min_val, digits),
          format_numbers(max_val, digits),
          format_numbers(median_val, digits))
}

# Function to generate a single Panel B row
generate_panelB_row <- function(data, varname, label, cluster_var = "district", digits = 3) {
  library(fixest)
  
  riot_yes <- data %>% filter(riot == 1)
  riot_no <- data %>% filter(riot == 0)
  
  mean_riot <- mean(riot_yes[[varname]], na.rm = TRUE)
  sd_riot <- sd(riot_yes[[varname]], na.rm = TRUE)
  mean_no_riot <- mean(riot_no[[varname]], na.rm = TRUE)
  sd_no_riot <- sd(riot_no[[varname]], na.rm = TRUE)
  diff <- mean_riot - mean_no_riot
  
  formula_str <- as.formula(paste(varname, "~ riot"))
  
  model <- feols(formula_str, data = data, cluster = cluster_var)
  p_value <- pvalue(model)["riot"]
  stars <- add_stars(p_value)
  
  
  # tryCatch({
  #   model <- feols(formula_str, data = data, cluster = cluster_var)
  #   p_value <- pvalue(model)["riot"]
  #   stars <- add_stars(p_value)
  # }, error = function(e) {
  #   t_result <- t.test(riot_yes[[varname]], riot_no[[varname]])
  #   p_value <- t_result$p.value
  #   stars <- add_stars(p_value)
  # })
  
  sprintf("%s & %s & %s & %s & %s & %s%s & %s \\\\",
          label,
          format_num(mean_riot, digits),
          format_num(sd_riot, digits),
          format_num(mean_no_riot, digits),
          format_num(sd_no_riot, digits),
          format_num(diff, digits), stars,
          format_num(p_value, 3))
}

# ============================================================================
# MAIN FUNCTION: Generate Summary Statistics
# ============================================================================

get_summary_stats_table <- function(rni_riots) {
  # tar_load(rni_riots)
  library(tidyverse)
  library(fixest)
  
  path_tracking_vector <- c()
  output_path <- "data/02_output/02_descriptive_table/"
  
  # Create output directory
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  # ============================================================================
  # PANEL A: FULL SAMPLE - OUTCOME VARIABLES
  # ============================================================================
  
  sumstats_muslim_rni <- generate_panelA_row(rni_riots, "rni_Muslim_lead", 
                                             "Muslim Name Index (t+1)", 3)
  save_track_object(sumstats_muslim_rni, writeLines, output_path = output_path)
  
  sumstats_hindu_rni <- generate_panelA_row(rni_riots, "rni_Hindu_lead", 
                                            "Hindu Name Index (t+1)", 3)
  save_track_object(sumstats_hindu_rni, writeLines, output_path = output_path)
  
  sumstats_muslim_n <- generate_panelA_row(rni_riots, "people_Muslim", 
                                           "Number of Muslims", 0)
  save_track_object(sumstats_muslim_n, writeLines, output_path = output_path)
  
  sumstats_hindu_n <- generate_panelA_row(rni_riots, "people_Hindu", 
                                          "Number of Hindus", 0)
  
  save_track_object(sumstats_hindu_n, writeLines, output_path = output_path)
  
  # ============================================================================
  # PANEL A: FULL SAMPLE - TREATMENT & INSTRUMENT
  # ============================================================================
  
  sumstats_riot <- generate_panelA_row(rni_riots, "riot", 
                                       "Riot occurrence", 3)
  save_track_object(sumstats_riot, writeLines, output_path = output_path)
  
  sumstats_nriot <- generate_panelA_row(rni_riots, "nriot", 
                                        "Number of riots", 2)
  save_track_object(sumstats_nriot, writeLines, output_path = output_path)
  
  sumstats_killed <- generate_panelA_row(rni_riots, "KILLED", 
                                         "Deaths in riots", 2)
  save_track_object(sumstats_killed, writeLines, output_path = output_path)
  
  sumstats_injured <- generate_panelA_row(rni_riots, "INJURED", 
                                          "Injuries in riots", 2)
  save_track_object(sumstats_injured, writeLines, output_path = output_path)
  
  sumstats_fridayfestival <- generate_panelA_row(rni_riots, "fridayfestival", 
                                                 "Friday Festival", 3)
  save_track_object(sumstats_fridayfestival, writeLines, output_path = output_path)
  
  # ============================================================================
  # PANEL B: RIOT VS NON-RIOT COMPARISON
  # ============================================================================
  
  sumstats_comparison_muslim_rni <- generate_panelB_row(rni_riots, "rni_Muslim_lead",
                                                        "Muslim Name Index (t+1)", 
                                                        "district", 3)
  save_track_object(sumstats_comparison_muslim_rni, writeLines, output_path = output_path)
  
  sumstats_comparison_hindu_rni <- generate_panelB_row(rni_riots, "rni_Hindu_lead",
                                                       "Hindu Name Index (t+1)", 
                                                       "district", 3)
  save_track_object(sumstats_comparison_hindu_rni, writeLines, output_path = output_path)
  
  sumstats_comparison_fridayfestival <- generate_panelB_row(rni_riots, "fridayfestival",
                                                            "Friday Festival", 
                                                            "district", 3)
  save_track_object(sumstats_comparison_fridayfestival, writeLines, output_path = output_path)
  
  return(path_tracking_vector)
}

# ============================================================================
# SEPARATE FUNCTION: Sample Information Table
# ============================================================================

get_sample_info_table <- function(rni_riots) {
  # tar_load(rni_riots)
  
  path_tracking_vector <- c()
  output_path <- "data/02_output/02_descriptive_table/"
  
  # Create output directory
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  # Calculate sample statistics
  n_obs <- nrow(rni_riots)
  n_districts <- length(unique(rni_riots$district))
  n_years <- length(unique(rni_riots$year))
  year_min <- min(rni_riots$year, na.rm = TRUE)
  year_max <- max(rni_riots$year, na.rm = TRUE)
  n_riot_years <- sum(rni_riots$riot == 1, na.rm = TRUE)
  pct_riot_years <- (n_riot_years / n_obs) * 100
  
  # Generate table rows
  sample_info_obs <- sprintf("Number of district-years & %s \\\\", 
                             format_comma(n_obs))
  sample_info_districts <- sprintf("Number of districts & %s \\\\", 
                                   format_comma(n_districts))
  sample_info_years <- sprintf("Number of years & %s (%s--%s) \\\\", 
                               n_years, year_min, year_max)
  sample_info_riots <- sprintf("District-years with riots & %s (%.1f\\%%) \\\\", 
                               format_comma(n_riot_years), pct_riot_years)
  
  # Save each row
  path_tracking_vector <- c(path_tracking_vector, 
                            save_track_object(sample_info_obs, writeLines, 
                                              output_path = output_path))
  
  path_tracking_vector <- c(path_tracking_vector, 
                            save_track_object(sample_info_districts, writeLines, 
                                              output_path = output_path))
  
  path_tracking_vector <- c(path_tracking_vector, 
                            save_track_object(sample_info_years, writeLines, 
                                              output_path = output_path))
  
  path_tracking_vector <- c(path_tracking_vector, 
                            save_track_object(sample_info_riots, writeLines, 
                                              output_path = output_path))
  
  return(path_tracking_vector)
}