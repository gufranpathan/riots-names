
# ============================================================================
# Benchmarks for docs/first_stage_iyer_20261019.md: how strong is the festival first stage
# in Iyer & Shrivastava's own data and in Goyal & van Noort's 339-district panel?
# ============================================================================

# Wald F of one instrument under several clusterings
benchmark_fits <- function(formula, data, instrument, clusters){
  library(fixest)
  F_stats <- sapply(clusters,function(cl){
    fit <- feols(formula,data=data,cluster=cl,notes=FALSE)
    unname((coef(fit)[instrument]/se(fit)[instrument])^2)
  })
  fit <- feols(formula,data=data,notes=FALSE)
  bind_cols(tibble(n=nobs(fit),coef=unname(coef(fit)[instrument])),as_tibble(as.list(F_stats)))
}

get_iyer_benchmark <- function(iyer_robustness_raw){
  # tar_load(iyer_robustness_raw)
  path_tracking_vector <- c()
  output_path <- "data/02_output/06_first_stage_iyer/"
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

  # Iyer's Table 5 first stage ("Tables 1-8 Figure 1.do"): election-year rows t with
  # L.riotnear200 ~ L.fes + L.bjprule + muslim urb lit ele tap time tsq (controls in t)
  iyer <- iyer_robustness_raw %>%
    zap_labels() %>%
    arrange(dist,year) %>%
    group_by(dist) %>%
    mutate(L_riotnear200=lag(riotnear200),
           L_riot=lag(riot),
           L_fes=lag(fes),
           L_bjprule=lag(bjprule),
           L_state_year=paste(st,year-1)) %>%
    ungroup() %>%
    mutate(state_year=paste(st,year))
  election_years <- iyer %>% filter(!is.na(ebjpvs))
  all_years <- iyer %>% filter(year>=1977,year<=1995)
  election_controls <- "+ L_bjprule + muslim + urb + lit + ele + tap + time + tsq | dist"
  specs <- tibble::tribble(
    ~label,                                             ~formula,                                           ~sample,     ~instrument,
    "Iyer Table 5 col 2: riotnear200, election years",  paste("L_riotnear200 ~ L_fes",election_controls),   "election",  "L_fes",
    "Iyer Table 5 col 4: riot, election years",         paste("L_riot ~ L_fes",election_controls),          "election",  "L_fes",
    "riotnear200 ~ fes + t + t2 | dist, 1977-1995",     "riotnear200 ~ fes + time + tsq | dist",            "1977-1995", "fes",
    "riot ~ fes + t + t2 | dist, 1977-1995",            "riot ~ fes + time + tsq | dist",                   "1977-1995", "fes"
  )
  benchmark_list <- lapply(seq_len(nrow(specs)),function(i){
    # cluster by the state-year of the instrument (t-1 in the election sample)
    if(specs$sample[i]=="election"){
      data <- election_years
      clusters <- list(F_district=~dist,F_state_year=~L_state_year,F_two_way=~dist+L_state_year,F_year=~year,F_state=~st)
    }else{
      data <- all_years
      clusters <- list(F_district=~dist,F_state_year=~state_year,F_two_way=~dist+state_year,F_year=~year,F_state=~st)
    }
    bind_cols(specs[i,],benchmark_fits(as.formula(specs$formula[i]),data,specs$instrument[i],clusters))
  })
  iyer_benchmark <- bind_rows(benchmark_list)
  save_track_object(iyer_benchmark,write.csv,output_extension="csv",output_path=output_path,row.names=FALSE)
  return(path_tracking_vector)
}

get_goyal_panel_first_stage <- function(riots_goyal_clean, festival_iyer, district_centroids){
  # tar_load(riots_goyal_clean)
  # tar_load(festival_iyer)
  # tar_load(district_centroids)
  # Goyal & van Noort's 339 districts, all states, no RNI restriction: which years and
  # states carry the first stage?
  path_tracking_vector <- c()
  output_path <- "data/02_output/06_first_stage_iyer/"
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

  goyal_locations <- locate_goyal_districts(riots_goyal_clean,district_centroids)
  distance_km <- haversine_km(goyal_locations$lon,goyal_locations$lat,goyal_locations$lon,goyal_locations$lat)
  goyal <- riots_goyal_clean %>%
    zap_labels() %>%
    select(dist,year,state_goyal,riot) %>%
    left_join(festival_iyer,by=c("state_goyal","year")) %>%
    mutate(time=year-1970,tsq=time^2,state_year=paste(state_goyal,year))
  kernel_list <- lapply(sort(unique(goyal$year)),function(yy){
    is_riot <- goyal$riot[goyal$year==yy][match(goyal_locations$dist,goyal$dist[goyal$year==yy])]==1
    riot_dist_km <- if(any(is_riot)) apply(distance_km[,is_riot,drop=FALSE],1,min) else rep(Inf,nrow(distance_km))
    tibble(dist=goyal_locations$dist,year=yy,riotnear200=exp(-riot_dist_km^2/(2*200^2)))
  })
  goyal <- goyal %>% left_join(bind_rows(kernel_list),by=c("dist","year"))

  clusters <- list(F_district=~dist,F_state_year=~state_year,F_two_way=~dist+state_year)
  samples <- bind_rows(
    expand_grid(window=c("1950-1995","1970-1995","1977-1995","1970-1976","1950-2006"),dropped="none"),
    expand_grid(window=c("1970-1995","1977-1995"),dropped=c("maharashtra","maharashtra+orissa")),
    expand_grid(window="1970-1995",dropped=sort(unique(goyal$state_goyal))))
  results_list <- list()
  for(i in seq_len(nrow(samples))){
    years <- as.numeric(str_split_1(samples$window[i],"-"))
    data <- goyal %>%
      filter(year>=years[1],year<=years[2],!state_goyal%in%str_split_1(samples$dropped[i],"\\+"))
    for(endog in c("riot","riotnear200")){
      results_list[[length(results_list)+1]] <- bind_cols(samples[i,],
                                                          tibble(endog=endog),
                                                          benchmark_fits(as.formula(paste(endog,"~ fes_iyer + time + tsq | dist")),data,"fes_iyer",clusters))
    }
  }
  goyal_panel_first_stage <- bind_rows(results_list)
  save_track_object(goyal_panel_first_stage,write.csv,output_extension="csv",output_path=output_path,row.names=FALSE)
  return(path_tracking_vector)
}

get_instrument_variation <- function(rni_riots_iyer, output_root = "data/02_output/"){
  # tar_load(rni_riots_iyer_frozen)
  # rni_riots_iyer <- rni_riots_iyer_frozen; output_root <- "data/02_output/frozen_rni/"
  # How much of the instrument is common to all states in a year?
  library(fixest)
  path_tracking_vector <- c()
  output_path <- paste0(output_root,"06_first_stage_iyer/")
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

  by_year <- rni_riots_iyer %>% group_by(year) %>% summarise(share_fes=mean(fes_iyer))
  instrument_variation <- tibble(
    years=n_distinct(rni_riots_iyer$year),
    states=n_distinct(rni_riots_iyer$state_goyal),
    state_years=n_distinct(rni_riots_iyer$state_year),
    years_fes_differs_across_states=sum(by_year$share_fes>0 & by_year$share_fes<1),
    years_fes_all_one=sum(by_year$share_fes==1),
    years_fes_all_zero=sum(by_year$share_fes==0),
    r2_fes_on_year_fe=unname(r2(feols(fes_iyer~1|year,data=rni_riots_iyer),"r2")),
    r2_fes_on_district_fe_trend=unname(r2(feols(fes_iyer~time+tsq|district_id,data=rni_riots_iyer),"r2")))
  save_track_object(instrument_variation,write.csv,output_extension="csv",output_path=output_path,row.names=FALSE)
  return(path_tracking_vector)
}

get_iyer_panel_summary <- function(rni_riots_iyer, output_root = "data/02_output/"){
  # tar_load(rni_riots_iyer_frozen)
  # rni_riots_iyer <- rni_riots_iyer_frozen; output_root <- "data/02_output/frozen_rni/"
  path_tracking_vector <- c()
  output_path <- paste0(output_root,"06_first_stage_iyer/")
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  iyer_panel_summary <- rni_riots_iyer %>% 
    summarise(rows=n(),
              districts=n_distinct(district_id),
              districts_on_1981_list=n_distinct(district_id[matched]),
              median_km_to_parent_if_not_on_list=median(parent_km[!matched]),
              states_pre2000=n_distinct(state_goyal),
              states_tcpd=n_distinct(state),
              first_year=min(year),
              last_year=max(year),
              mean_riot=mean(riot),
              mean_riotnear200=mean(riotnear200),
              sd_riotnear200=sd(riotnear200),
              mean_riotall200=mean(riotall200),
              mean_fes_iyer=mean(fes_iyer),
              mean_rni_Muslim_lead=mean(rni_Muslim_lead),
              mean_rni_Hindu_lead=mean(rni_Hindu_lead))
  save_track_object(iyer_panel_summary,write.csv,output_extension="csv",output_path=output_path,row.names=FALSE)

  iyer_panel_by_state <- rni_riots_iyer %>%
    group_by(state_goyal,state) %>%
    summarise(districts=n_distinct(district_id),
              districts_on_1981_list=n_distinct(district_id[matched]),
              district_years=n(),
              riot_district_years=sum(riot),
              mean_riotnear200=mean(riotnear200),
              voters_scored_muslim=sum(people_Muslim_lead),
              voters_scored_hindu=sum(people_Hindu_lead),
              mean_rni_Muslim_lead=weighted.mean(rni_Muslim_lead,people_Muslim_lead),
              mean_rni_Hindu_lead=weighted.mean(rni_Hindu_lead,people_Hindu_lead),
              .groups="drop")
  save_track_object(iyer_panel_by_state,write.csv,output_extension="csv",output_path=output_path,row.names=FALSE)
  return(path_tracking_vector)
}
