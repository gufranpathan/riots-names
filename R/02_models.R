


get_iv_models <- function(rni_riots){
  # tar_load(rni_riots)
  library(fixest)
  
  model1m <- feols(rni_Muslim_lead ~ 1 | riot ~ fridayfestival, data = rni_riots,cluster="district")
  model2m <- feols(rni_Muslim_lead ~ 1 | district | riot ~ fridayfestival, data = rni_riots, cluster="district")
  model3m <- feols(rni_Muslim_lead ~ year | district | riot ~ fridayfestival, data = rni_riots, cluster="district")
  model4m <- feols(rni_Muslim_lead ~ 1 | district + year | riot ~ fridayfestival, data = rni_riots, cluster="district")
  
  muslim_models <- list(model1m,model2m,model3m,model4m)
  
  
  model1h <- feols(rni_Hindu_lead ~ 1 | riot ~ fridayfestival, data = rni_riots, cluster="district")
  model2h <- feols(rni_Hindu_lead ~ 1 | district | riot ~ fridayfestival, data = rni_riots, cluster="district")
  model3h <- feols(rni_Hindu_lead ~ year | district | riot ~ fridayfestival, data = rni_riots, cluster="district")
  model4h <- feols(rni_Hindu_lead ~ 1 | district + year | riot ~ fridayfestival, data = rni_riots, cluster="district")
  
  hindu_models <- list(model1h,model2h,model3h,model4h)
  
  iv_models <- list('muslim_models'=muslim_models,'hindu_models'=hindu_models)
  
  return(iv_models)
  
}


# Function to extract coefficient, standard error, and stars
get_coef_stats <- function(model, var_name = "fit_riot") {
  coef_val <- coef(model)[var_name]
  se_val <- se(model)[var_name]
  
  # Calculate p-value and stars
  t_stat <- coef_val / se_val
  p_val <- 2 * pt(-abs(t_stat), df = model$nobs - length(coef(model)))
  
  stars <- ""
  if (p_val < 0.01) stars <- "***"
  else if (p_val < 0.05) stars <- "**"
  else if (p_val < 0.1) stars <- "*"
  
  # Format coefficient and SE
  coef_str <- sprintf("$%.3f^{%s}$", coef_val, stars)
  se_str <- sprintf("(%.3f)", se_val)
  
  return(list(coef = coef_str, se = se_str))
}

get_table1_latex <- function(iv_models){
  # tar_load(iv_models)
  library(fixest)
  
  output_path <- 'data/02_output/01_table1/'
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  path_tracking_vector <- c()
  
  models_m <- iv_models[['muslim_models']]
  
  muslim_stats <- lapply(models_m, get_coef_stats)
  muslim_obs <- sapply(models_m, function(x) format(x$nobs, big.mark = ","))
  muslim_r2 <- sapply(models_m, function(x) sprintf("%.3f", r2(x)['r2']))
  
  coef_line_m <- paste(sapply(muslim_stats,FUN = function(x)x$coef),collapse =" & ")
  se_line_m <- paste(sapply(muslim_stats,FUN = function(x)x$se),collapse =" & ")
  obs_line_m <- paste(muslim_obs,collapse =" & ")
  r2_line_m <- paste(muslim_r2,collapse =" & ")
  
  save_track_object(coef_line_m,writeLines,output_path=output_path)
  save_track_object(se_line_m,writeLines,output_path=output_path)
  save_track_object(obs_line_m,writeLines,output_path=output_path)
  save_track_object(r2_line_m,writeLines,output_path=output_path)
  
  models_h <- iv_models[['hindu_models']]
  
  hindu_stats <- lapply(models_h, get_coef_stats)
  hindu_obs <- sapply(models_h, function(x) format(x$nobs, big.mark = ","))
  hindu_r2 <- sapply(models_h, function(x) sprintf("%.3f", r2(x)['r2']))
  
  coef_line_h <- paste(sapply(hindu_stats,FUN = function(x)x$coef),collapse =" & ")
  se_line_h <- paste(sapply(hindu_stats,FUN = function(x)x$se),collapse =" & ")
  obs_line_h <- paste(hindu_obs,collapse =" & ")
  r2_line_h <- paste(hindu_r2,collapse =" & ")
  
  save_track_object(coef_line_h,writeLines,output_path='data/02_output/01_table1/')
  save_track_object(se_line_h,writeLines,output_path='data/02_output/01_table1/')
  save_track_object(obs_line_h,writeLines,output_path='data/02_output/01_table1/')
  save_track_object(r2_line_h,writeLines,output_path='data/02_output/01_table1/')
  
  return(path_tracking_vector)
}


# ============================================================================
# First-Stage Results Table Generator
# ============================================================================

# Function to extract first-stage coefficient, standard error, and stars
get_first_stage_stats <- function(model, var_name = "fridayfestival") {
  # model <- models[[1]]
  # Extract first stage results
  fs_summary <- summary(model, stage = 1)
  
  # Get coefficient and standard error
  coef_val <- coeftable(fs_summary)[var_name, "Estimate"]
  se_val <- coeftable(fs_summary)[var_name, "Std. Error"]
  p_val <- coeftable(fs_summary)[var_name, "Pr(>|t|)"]
  
  # Calculate stars
  stars <- ""
  if (p_val < 0.01) stars <- "***"
  else if (p_val < 0.05) stars <- "**"
  else if (p_val < 0.1) stars <- "*"
  
  # Format coefficient and SE
  coef_str <- sprintf("$%.4f^{%s}$", coef_val, stars)
  se_str <- sprintf("(%.4f)", se_val)
  
  return(list(coef = coef_str, se = se_str))
}

# Main function to generate first-stage table
get_first_stage_table <- function(iv_models) {
  # tar_load(iv_models)
  library(fixest)
  
  path_tracking_vector <- c()
  output_path <- "data/02_output/03_first_stage/"
  
  # Create output directory
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  # Extract Muslim models (we only need one set since first stage is the same)
  models <- iv_models[['muslim_models']]
  
  # ============================================================================
  # Extract First-Stage Statistics
  # ============================================================================
  
  # Get coefficient and SE for each model
  fs_stats <- lapply(models, get_first_stage_stats)
  
  # Get F-statistics
  fs_fstats <- sapply(models, function(x) fitstat(x, "ivf",simplify = T)[['stat']])
  
  # Get observations
  fs_obs <- sapply(models, function(x) format(x$nobs, big.mark = ","))
  
  # Get R-squared from first stage
  fs_r2 <- sapply(models, function(x) {
    fs_summary <- r2(summary(x,stage=1))['r2']
    sprintf("%.3f", fs_summary)
  })
  
  # ============================================================================
  # Format LaTeX Table Rows
  # ============================================================================
  
  # Coefficient line
  fs_coef_line <- paste(sapply(fs_stats, function(x) x$coef), collapse = " & ")
  save_track_object(fs_coef_line, writeLines, output_path = output_path)
  
  # Standard error line
  fs_se_line <- paste(sapply(fs_stats, function(x) x$se), collapse = " & ")
  save_track_object(fs_se_line, writeLines, output_path = output_path)
  
  # F-statistic line
  fs_fstat_line <- paste(sprintf("%.2f", fs_fstats), collapse = " & ")
  save_track_object(fs_fstat_line, writeLines, output_path = output_path)
  
  # Observations line
  fs_obs_line <- paste(fs_obs, collapse = " & ")
  save_track_object(fs_obs_line, writeLines, output_path = output_path)
  
  # R-squared line
  fs_r2_line <- paste(fs_r2, collapse = " & ")
  save_track_object(fs_r2_line, writeLines, output_path = output_path)
  
  return(path_tracking_vector)
}




# ============================================================================
# Detailed Tables
# ============================================================================

# Function to extract stats for OLS and RF (different variable names)
get_coef_stats_generic <- function(model, var_name) {
  if (!var_name %in% names(coef(model))) {
    return(list(coef = "$--$", se = "$--$"))
  }
  
  coef_val <- coef(model)[var_name]
  se_val <- se(model)[var_name]
  
  # Calculate p-value and stars
  t_stat <- coef_val / se_val
  p_val <- 2 * pt(-abs(t_stat), df = model$nobs - length(coef(model)))
  
  stars <- ""
  if (p_val < 0.01) stars <- "***"
  else if (p_val < 0.05) stars <- "**"
  else if (p_val < 0.1) stars <- "*"
  
  # Format coefficient and SE
  coef_str <- sprintf("$%.3f^{%s}$", coef_val, stars)
  se_str <- sprintf("(%.3f)", se_val)
  
  return(list(coef = coef_str, se = se_str))
}


# Function to run all three types of models for a given specification
get_all_model_types <- function(rni_riots, outcome_var, spec_num, cluster_var = "district") {
  library(fixest)
  
  # Define the specification based on spec_num
  if (spec_num == 1) {
    # No fixed effects
    ols_formula <- as.formula(paste(outcome_var, "~ riot"))
    rf_formula <- as.formula(paste(outcome_var, "~ fridayfestival"))
    iv_formula <- as.formula(paste(outcome_var, "~ 1 | riot ~ fridayfestival"))
    fe_formula <- NULL
  } else if (spec_num == 2) {
    # District FE
    ols_formula <- as.formula(paste(outcome_var, "~ riot | district"))
    rf_formula <- as.formula(paste(outcome_var, "~ fridayfestival | district"))
    iv_formula <- as.formula(paste(outcome_var, "~ 1 | district | riot ~ fridayfestival"))
    fe_formula <- "district"
  } else if (spec_num == 3) {
    # District FE + Linear time trend
    ols_formula <- as.formula(paste(outcome_var, "~ riot + year | district"))
    rf_formula <- as.formula(paste(outcome_var, "~ fridayfestival + year | district"))
    iv_formula <- as.formula(paste(outcome_var, "~ year | district | riot ~ fridayfestival"))
    fe_formula <- "district"
  } else if (spec_num == 4) {
    # District FE + Year FE
    ols_formula <- as.formula(paste(outcome_var, "~ riot | district + year"))
    rf_formula <- as.formula(paste(outcome_var, "~ fridayfestival | district + year"))
    iv_formula <- as.formula(paste(outcome_var, "~ 1 | district + year | riot ~ fridayfestival"))
    fe_formula <- "district + year"
  }
  
  # Run OLS model
  ols_model <- feols(ols_formula, data = rni_riots, cluster = cluster_var)
  
  # Run Reduced Form model
  rf_model <- feols(rf_formula, data = rni_riots, cluster = cluster_var)
  
  # Run IV model
  iv_model <- feols(iv_formula, data = rni_riots, cluster = cluster_var)
  
  return(list(ols = ols_model, rf = rf_model, iv = iv_model))
}

get_model_tables <- function(rni_riots, religion = c("muslim", "hindu")) {
  # tar_load(rni_riots)
  # religion <- "muslim"
  # Validate religion argument
  religion <- match.arg(religion)
  
  library(fixest)
  
  path_tracking_vector <- c()
  
  # Construct outcome variable name and output path based on religion
  
  outcome_var <- paste0("rni_",str_to_title(religion),"_lead")
  output_path <- paste0("data/02_output/05_table_",religion,"/")

  # Create output directory
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  # Run all models for all 4 specifications
  all_models <- list()
  for (i in 1:4) {
    all_models[[i]] <- get_all_model_types(rni_riots, outcome_var, i, "district")
  }
  
  # Extract OLS estimates
  ols_stats <- lapply(all_models, function(x) get_coef_stats_generic(x$ols, "riot"))
  ols_coef_line <- paste(sapply(ols_stats, function(x) x$coef), collapse = " & ")
  ols_se_line <- paste(sapply(ols_stats, function(x) x$se), collapse = " & ")
  
  save_track_object(ols_coef_line, writeLines, output_path = output_path)
  save_track_object(ols_se_line, writeLines, output_path = output_path)
  
  # Extract Reduced Form estimates
  rf_stats <- lapply(all_models, function(x) get_coef_stats_generic(x$rf, "fridayfestival"))
  rf_coef_line <- paste(sapply(rf_stats, function(x) x$coef), collapse = " & ")
  rf_se_line <- paste(sapply(rf_stats, function(x) x$se), collapse = " & ")
  
  save_track_object(rf_coef_line, writeLines, output_path = output_path)
  save_track_object(rf_se_line, writeLines, output_path = output_path)
  
  # Extract IV estimates
  iv_stats <- lapply(all_models, function(x) get_coef_stats_generic(x$iv, "fit_riot"))
  iv_coef_line <- paste(sapply(iv_stats, function(x) x$coef), collapse = " & ")
  iv_se_line <- paste(sapply(iv_stats, function(x) x$se), collapse = " & ")
  
  save_track_object(iv_coef_line, writeLines, output_path = output_path)
  save_track_object(iv_se_line, writeLines, output_path = output_path)
  
  # Extract observations and R-squared from IV models
  obs <- sapply(all_models, function(x) format(x$iv$nobs, big.mark = ","))
  r2 <- sapply(all_models, function(x) sprintf("%.3f", r2(x$iv)['r2']))
  
  obs_line <- paste(obs, collapse = " & ")
  r2_line <- paste(r2, collapse = " & ")
  
  save_track_object(obs_line, writeLines, output_path = output_path)
  save_track_object(r2_line, writeLines, output_path = output_path)
  
  # Extract first-stage F-statistics for IV models
  iv_f_stats <- sapply(all_models, function(x) {
    f_stat <- fitstat(x$iv, "ivf",simplify = T)[['stat']]
    if (is.null(f_stat) || is.na(f_stat)) return("--")
    sprintf("%.2f", f_stat)
  })
  
  f_stat_line <- paste(iv_f_stats, collapse = " & ")
  save_track_object(f_stat_line, writeLines, output_path = output_path)
  
  return(path_tracking_vector)
}
