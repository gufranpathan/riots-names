


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
  
  path_tracking_vector <- c()
  
  models_m <- iv_models[['muslim_models']]
  
  muslim_stats <- lapply(models_m, get_coef_stats)
  muslim_obs <- sapply(models_m, function(x) format(x$nobs, big.mark = ","))
  muslim_r2 <- sapply(models_m, function(x) sprintf("%.3f", r2(x)['r2']))

  coef_line_m <- paste(sapply(muslim_stats,FUN = function(x)x$coef),collapse =" & ")
  se_line_m <- paste(sapply(muslim_stats,FUN = function(x)x$se),collapse =" & ")
  obs_line_m <- paste(muslim_obs,collapse =" & ")
  r2_line_m <- paste(muslim_r2,collapse =" & ")
  
  save_track_object(coef_line_m,writeLines,output_path='data/02_output/01_table1/')
  save_track_object(se_line_m,writeLines,output_path='data/02_output/01_table1/')
  save_track_object(obs_line_m,writeLines,output_path='data/02_output/01_table1/')
  save_track_object(r2_line_m,writeLines,output_path='data/02_output/01_table1/')
  
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


