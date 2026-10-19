
# ============================================================================
# Iyer & Shrivastava (2018) style IV models on rni_riots_iyer_frozen and _annual (riot years 1970-1995)
# ============================================================================

iyer_controls <- "bjprule + muslim + urb + lit + ele + tap"

# Columns of the Iyer-style tables. exog = exogenous regressors besides the fixed effects.
iyer_specs <- tibble::tribble(
  ~spec, ~label,                         ~endog,        ~instrument,      ~exog,                                  ~fe,
  "1",   "Current spec: own riot",       "riot",        "fridayfestival", "",                                     "district_id",
  "2",   "Own riot, Iyer controls",      "riot",        "fes_iyer",       paste(iyer_controls, "+ time + tsq"),  "district_id",
  "3",   "Kernel, quadratic trend",      "riotnear200", "fes_iyer",       "time + tsq",                           "district_id",
  "4",   "Kernel, Iyer controls (main)", "riotnear200", "fes_iyer",       paste(iyer_controls, "+ time + tsq"),  "district_id",
  "5",   "Kernel-weighted riot count",   "riotall200",  "fes_iyer",       paste(iyer_controls, "+ time + tsq"),  "district_id",
  "6",   "Spatial instrument, year FE",  "riotall200",  "fesnormdist200", iyer_controls,                          "district_id + year"
)

iyer_formula <- function(spec_row, outcome, type){
  exog <- spec_row$exog
  plus_exog <- if(exog=="") "" else paste("+",exog)
  formula_string <- switch(type,
                           iv=paste(outcome,"~",if(exog=="") "1" else exog,"|",spec_row$fe,"|",spec_row$endog,"~",spec_row$instrument),
                           ols=paste(outcome,"~",spec_row$endog,plus_exog,"|",spec_row$fe),
                           rf=paste(outcome,"~",spec_row$instrument,plus_exog,"|",spec_row$fe),
                           fs=paste(spec_row$endog,"~",spec_row$instrument,plus_exog,"|",spec_row$fe))
  return(as.formula(formula_string))
}

# Iyer clusters by district; the instrument varies by state-year, so report both (and two-way)
iyer_clusters <- list(district=~district_id,
                      state_year=~state_year,
                      two_way=~district_id+state_year)

get_iv_models_iyer <- function(rni_riots_iyer){
  # tar_load(rni_riots_iyer_frozen)
  # rni_riots_iyer <- rni_riots_iyer_frozen
  library(fixest)

  iv_models_iyer <- list()
  for(outcome in c("rni_Muslim_lead","rni_Hindu_lead")){
    for(i in seq_len(nrow(iyer_specs))){
      spec_row <- iyer_specs[i,]
      iv_models_iyer[[outcome]][[spec_row$spec]] <- list(
        iv=feols(iyer_formula(spec_row,outcome,"iv"),data=rni_riots_iyer,cluster=~district_id),
        ols=feols(iyer_formula(spec_row,outcome,"ols"),data=rni_riots_iyer,cluster=~district_id),
        rf=feols(iyer_formula(spec_row,outcome,"rf"),data=rni_riots_iyer,cluster=~district_id))
    }
  }
  return(iv_models_iyer)
}

# First-stage coefficient and Wald F (= Kleibergen-Paap F with one instrument) by clustering
first_stage_fits <- function(spec_row, data, weights = NULL){
  library(fixest)
  fits <- lapply(iyer_clusters,function(cl){
    feols(iyer_formula(spec_row,NULL,"fs"),data=data,cluster=cl,weights=weights,notes=FALSE)
  })
  stats <- sapply(fits,function(fit){
    ct <- coeftable(fit)[spec_row$instrument,]
    c(coef=unname(ct["Estimate"]),se=unname(ct["Std. Error"]),F=unname((ct["Estimate"]/ct["Std. Error"])^2))
  })
  iid_fit <- feols(iyer_formula(spec_row,NULL,"fs"),data=data,vcov="iid",weights=weights,notes=FALSE)
  state_fit <- feols(iyer_formula(spec_row,NULL,"fs"),data=data,cluster=~state_goyal,weights=weights,notes=FALSE)
  year_fit <- feols(iyer_formula(spec_row,NULL,"fs"),data=data,cluster=~year,weights=weights,notes=FALSE)
  tibble(n=nobs(fits$district),
         coef=stats["coef","district"],
         se_district=stats["se","district"],
         se_state_year=stats["se","state_year"],
         F_district=stats["F","district"],
         F_state_year=stats["F","state_year"],
         F_two_way=stats["F","two_way"],
         F_state=unname((coef(state_fit)[spec_row$instrument]/se(state_fit)[spec_row$instrument])^2),
         F_year=unname((coef(year_fit)[spec_row$instrument]/se(year_fit)[spec_row$instrument])^2),
         F_iid=unname((coef(iid_fit)[spec_row$instrument]/se(iid_fit)[spec_row$instrument])^2),
         r2=unname(r2(fits$district,"r2")))
}

get_first_stage_iyer_grid <- function(rni_riots_iyer, output_root = "data/02_output/"){
  # tar_load(rni_riots_iyer_frozen)
  # rni_riots_iyer <- rni_riots_iyer_frozen; output_root <- "data/02_output/frozen_rni/"
  path_tracking_vector <- c()
  output_path <- paste0(output_root,"06_first_stage_iyer/")
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

  main <- iyer_specs %>% filter(spec=="4")
  variants <- bind_rows(
    iyer_specs %>% mutate(sample="all",weights="none"),
    tibble(spec=paste0("4-h",c(100,150,250,300)),
           label=paste0("Main spec, bandwidth ",c(100,150,250,300)," km"),
           endog=paste0("riotnear",c(100,150,250,300))),
    tibble(spec="4-goyal",label="Main spec, Goyal's fridayfestival",instrument="fridayfestival"),
    tibble(spec="4-matched",label="Main spec, districts on the 1981 list only",sample="matched"),
    tibble(spec="4-yearfe",label="Main spec, year FE instead of trend",exog=iyer_controls,fe="district_id + year"),
    tibble(spec="4-weighted",label="Main spec, weighted by RNI sample size",weights="people_lead"),
    tibble(spec="5-weighted",label="Kernel-weighted count, weighted by RNI sample size",endog="riotall200",weights="people_lead")
  ) %>%
    mutate(endog=coalesce(endog,main$endog),
           instrument=coalesce(instrument,main$instrument),
           exog=coalesce(exog,main$exog),
           fe=coalesce(fe,main$fe),
           sample=coalesce(sample,"all"),
           weights=coalesce(weights,"none"))

  grid_list <- list()
  for(window in list(c(1970,1995),c(1977,1995))){
    for(i in seq_len(nrow(variants))){
      spec_row <- variants[i,]
      data <- rni_riots_iyer %>% filter(year>=window[1],year<=window[2])
      if(spec_row$sample=="matched") data <- data %>% filter(matched)
      weights <- if(spec_row$weights=="none") NULL else as.formula(paste("~",spec_row$weights))
      grid_list[[length(grid_list)+1]] <- bind_cols(tibble(window=paste(window,collapse="-")),
                                                    spec_row,
                                                    first_stage_fits(spec_row,data,weights))
    }
  }
  first_stage_iyer_grid <- bind_rows(grid_list)
  save_track_object(first_stage_iyer_grid,write.csv,output_extension="csv",output_path=output_path,row.names=FALSE)
  return(path_tracking_vector)
}

format_estimate <- function(estimate, std_error, p_value, digits = 3){
  list(coef=sprintf(paste0("$%.",digits,"f^{%s}$"),estimate,add_stars(p_value)),
       se=sprintf(paste0("(%.",digits,"f)"),std_error))
}

get_first_stage_iyer_table <- function(rni_riots_iyer, output_root = "data/02_output/"){
  # tar_load(rni_riots_iyer_frozen)
  # rni_riots_iyer <- rni_riots_iyer_frozen; output_root <- "data/02_output/frozen_rni/"
  library(fixest)
  path_tracking_vector <- c()
  output_path <- paste0(output_root,"06_first_stage_iyer/")
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

  fits <- lapply(seq_len(nrow(iyer_specs)),function(i){
    feols(iyer_formula(iyer_specs[i,],NULL,"fs"),data=rni_riots_iyer,cluster=~district_id)
  })
  stats <- lapply(seq_len(nrow(iyer_specs)),function(i) first_stage_fits(iyer_specs[i,],rni_riots_iyer))
  fs_iyer_estimates <- lapply(seq_len(nrow(iyer_specs)),function(i){
    instrument <- iyer_specs$instrument[i]
    format_estimate(coef(fits[[i]])[instrument],se(fits[[i]])[instrument],pvalue(fits[[i]])[instrument],digits=4)
  })

  fs_iyer_endog_line <- paste(iyer_specs$endog,collapse=" & ")
  fs_iyer_instrument_line <- paste(iyer_specs$instrument,collapse=" & ")
  fs_iyer_coef_line <- paste(sapply(fs_iyer_estimates,function(x) x$coef),collapse=" & ")
  fs_iyer_se_line <- paste(sapply(fs_iyer_estimates,function(x) x$se),collapse=" & ")
  fs_iyer_se_state_year_line <- paste(sprintf("[%.4f]",sapply(stats,function(x) x$se_state_year)),collapse=" & ")
  fs_iyer_fstat_line <- paste(sprintf("%.2f",sapply(stats,function(x) x$F_district)),collapse=" & ")
  fs_iyer_fstat_state_year_line <- paste(sprintf("%.2f",sapply(stats,function(x) x$F_state_year)),collapse=" & ")
  fs_iyer_fstat_two_way_line <- paste(sprintf("%.2f",sapply(stats,function(x) x$F_two_way)),collapse=" & ")
  fs_iyer_controls_line <- paste(if_else(str_detect(iyer_specs$exog,"bjprule"),"Yes","No"),collapse=" & ")
  fs_iyer_trend_line <- paste(if_else(str_detect(iyer_specs$exog,"tsq"),"Yes","No"),collapse=" & ")
  fs_iyer_year_fe_line <- paste(if_else(str_detect(iyer_specs$fe,"year"),"Yes","No"),collapse=" & ")
  fs_iyer_obs_line <- paste(sapply(stats,function(x) format(x$n,big.mark=",")),collapse=" & ")
  fs_iyer_r2_line <- paste(sprintf("%.3f",sapply(stats,function(x) x$r2)),collapse=" & ")

  for(line_name in ls(pattern="^fs_iyer_.*_line$")){
    save_track_object(as.name(line_name),writeLines,output_path=output_path)
  }
  return(path_tracking_vector)
}

get_iyer_model_tables <- function(iv_models_iyer, rni_riots_iyer, religion = c("muslim", "hindu"), output_root = "data/02_output/"){
  # tar_load(c(iv_models_iyer_frozen, rni_riots_iyer_frozen))
  # iv_models_iyer <- iv_models_iyer_frozen; rni_riots_iyer <- rni_riots_iyer_frozen
  # religion <- "muslim"; output_root <- "data/02_output/frozen_rni/"
  religion <- match.arg(religion)
  library(fixest)
  path_tracking_vector <- c()
  outcome_var <- paste0("rni_",str_to_title(religion),"_lead")
  output_path <- paste0(output_root,"07_table_iyer_",religion,"/")
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

  models <- iv_models_iyer[[outcome_var]]
  estimate_line <- function(type, part, cluster = NULL){
    estimates <- lapply(seq_len(nrow(iyer_specs)),function(i){
      model <- models[[iyer_specs$spec[i]]][[type]]
      if(!is.null(cluster)){
        model <- summary(model,cluster=list(rni_riots_iyer[[cluster]][obs(model)]))
      }
      variable <- switch(type,
                         ols=iyer_specs$endog[i],
                         rf=iyer_specs$instrument[i],
                         iv=paste0("fit_",iyer_specs$endog[i]))
      format_estimate(coef(model)[variable],se(model)[variable],pvalue(model)[variable],digits=4)
    })
    paste(sapply(estimates,function(x) x[[part]]),collapse=" & ")
  }

  iyer_ols_coef_line <- estimate_line("ols","coef")
  iyer_ols_se_line <- estimate_line("ols","se")
  iyer_rf_coef_line <- estimate_line("rf","coef")
  iyer_rf_se_line <- estimate_line("rf","se")
  iyer_iv_coef_line <- estimate_line("iv","coef")
  iyer_iv_se_line <- estimate_line("iv","se")
  # same 2SLS estimate, stars and SE from state-year clustering, in brackets
  iyer_iv_coef_state_year_line <- estimate_line("iv","coef",cluster="state_year")
  iyer_iv_se_state_year_line <- str_replace_all(estimate_line("iv","se",cluster="state_year"),c("\\("="[","\\)"="]"))

  stats <- lapply(seq_len(nrow(iyer_specs)),function(i) first_stage_fits(iyer_specs[i,],rni_riots_iyer))
  iyer_f_stat_line <- paste(sprintf("%.2f",sapply(stats,function(x) x$F_district)),collapse=" & ")
  iyer_f_stat_state_year_line <- paste(sprintf("%.2f",sapply(stats,function(x) x$F_state_year)),collapse=" & ")
  iyer_obs_line <- paste(sapply(iyer_specs$spec,function(s) format(nobs(models[[s]]$iv),big.mark=",")),collapse=" & ")
  iyer_r2_line <- paste(sapply(iyer_specs$spec,function(s) sprintf("%.3f",r2(models[[s]]$iv)['r2'])),collapse=" & ")

  for(line_name in ls(pattern="^iyer_.*_line$")){
    save_track_object(as.name(line_name),writeLines,output_path=output_path)
  }
  return(path_tracking_vector)
}

# Anderson-Rubin 95% set for one endogenous regressor and one instrument: all beta with
# (pi_y - beta*pi_x)^2 <= crit * Var(pi_y - beta*pi_x). Unbounded when the first stage is
# insignificant at the same level, which is when the usual 2SLS interval is misleading.
anderson_rubin_set <- function(pi_y, pi_x, V, crit){
  a <- pi_x^2 - crit*V[2,2]
  b <- -2*(pi_x*pi_y - crit*V[1,2])
  c <- pi_y^2 - crit*V[1,1]
  disc <- b^2 - 4*a*c
  roots <- if(disc>0) sort((-b+c(-1,1)*sqrt(disc))/(2*a)) else c(NA,NA)
  if(a>0) return(tibble(ar_set="interval",ar_lower=roots[1],ar_upper=roots[2]))
  if(disc>0) return(tibble(ar_set="two rays: (-Inf, lower] and [upper, Inf)",ar_lower=roots[1],ar_upper=roots[2]))
  return(tibble(ar_set="whole real line",ar_lower=-Inf,ar_upper=Inf))
}

get_anderson_rubin_iyer <- function(rni_riots_iyer, output_root = "data/02_output/"){
  # tar_load(rni_riots_iyer_frozen)
  # rni_riots_iyer <- rni_riots_iyer_frozen; output_root <- "data/02_output/frozen_rni/"
  library(fixest)
  path_tracking_vector <- c()
  output_path <- paste0(output_root,"06_first_stage_iyer/")
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

  ar_list <- list()
  for(window in list(c(1970,1995),c(1977,1995))){
    data <- rni_riots_iyer %>% filter(year>=window[1],year<=window[2])
    for(spec_row in split(iyer_specs %>% filter(spec%in%c("2","4","5")),~spec)){
      exog_vars <- if(spec_row$exog=="") character(0) else str_split_1(spec_row$exog," \\+ ")
      for(outcome in c("rni_Muslim_lead","rni_Hindu_lead")){
        # stack reduced form (eq y) and first stage (eq x) to get their joint clustered covariance
        stacked <- bind_rows(data %>% mutate(eq="y",value=.data[[outcome]]),
                             data %>% mutate(eq="x",value=.data[[spec_row$endog]]))
        for(v in c(spec_row$instrument,exog_vars)){
          stacked[[paste0(v,"_y")]] <- stacked[[v]]*(stacked$eq=="y")
          stacked[[paste0(v,"_x")]] <- stacked[[v]]*(stacked$eq=="x")
        }
        rhs <- paste(c(paste0(c(spec_row$instrument,exog_vars),"_y"),paste0(c(spec_row$instrument,exog_vars),"_x")),collapse=" + ")
        fe <- paste(paste0("eq^",str_split_1(spec_row$fe," \\+ ")),collapse=" + ")
        iv_model <- feols(iyer_formula(spec_row,outcome,"iv"),data=data,cluster=~district_id)
        for(cluster_name in names(iyer_clusters)){
          stacked_fit <- feols(as.formula(paste("value ~",rhs,"|",fe)),data=stacked,cluster=iyer_clusters[[cluster_name]])
          z <- paste0(spec_row$instrument,c("_y","_x"))
          pi_hat <- coef(stacked_fit)[z]
          V <- vcov(stacked_fit)[z,z]
          n_clusters <- min(sapply(all.vars(iyer_clusters[[cluster_name]]),function(v) n_distinct(data[[v]])))
          crit <- qt(0.975,df=n_clusters-1)^2
          iv_summary <- summary(iv_model,cluster=iyer_clusters[[cluster_name]])
          ar_list[[length(ar_list)+1]] <- bind_cols(
            tibble(window=paste(window,collapse="-"),
                   spec=spec_row$spec,
                   label=spec_row$label,
                   outcome=outcome,
                   cluster=cluster_name,
                   n_clusters=n_clusters,
                   tsls=unname(coef(iv_summary)[paste0("fit_",spec_row$endog)]),
                   tsls_se=unname(se(iv_summary)[paste0("fit_",spec_row$endog)]),
                   tsls_p=unname(pvalue(iv_summary)[paste0("fit_",spec_row$endog)]),
                   first_stage_F=unname(pi_hat[2]^2/V[2,2]),
                   reduced_form=unname(pi_hat[1]),
                   ar_p_beta0=2*pt(-abs(pi_hat[1]/sqrt(V[1,1])),df=n_clusters-1)),
            anderson_rubin_set(pi_hat[1],pi_hat[2],V,crit))
        }
      }
    }
  }
  anderson_rubin_iyer <- bind_rows(ar_list)
  save_track_object(anderson_rubin_iyer,write.csv,output_extension="csv",output_path=output_path,row.names=FALSE)
  return(path_tracking_vector)
}
