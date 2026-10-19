
# Fill earlier years with each district's linear trend over base_years. Goyal & van Noort's
# 1971-1980 controls are exactly this back-extrapolation of Iyer's 1981-1991 census values.
extend_back_linear <- function(controls, var, base_years = 1981:1991){
  controls %>%
    group_by(dist) %>%
    group_modify(function(d, key){
      base <- d %>% filter(year%in%base_years,!is.na(.data[[var]]))
      if(nrow(base)<2) base <- d %>% filter(!is.na(.data[[var]])) %>% slice_min(year,n=11)
      fit <- lm(reformulate("year",var),data=base)
      fill <- is.na(d[[var]]) & d$year<min(base$year)
      d[[var]][fill] <- predict(fit,newdata=d[fill,])
      d
    }) %>%
    ungroup()
}

get_district_controls <- function(riots_goyal_clean, iyer_robustness_raw){
  # tar_load(riots_goyal_clean)
  # tar_load(iyer_robustness_raw)
  # Iyer's controls by Goyal district-year, 1969-2006: Muslim share, urbanisation, literacy,
  # electricity (Goyal; from 1971) and tap water (Iyer; from 1981), extended back linearly.
  # Before 1981 they are trends, not census measurements (some go below zero, as in Goyal).
  district_controls <- riots_goyal_clean %>%
    zap_labels() %>%
    filter(year>=1969) %>%
    select(dist,year,
           muslim=muslim_pop,
           urb=urban_pop,
           lit=perc_literate,
           ele=perc_electricity,
           bjprule) %>%
    left_join(iyer_robustness_raw %>% zap_labels() %>% select(dist,year,tap),by=c("dist","year")) %>%
    mutate(bjprule=replace_na(bjprule,0)) # NA before 1977; the BJP was founded in 1980
  for(var in c("muslim","urb","lit","ele","tap")){
    district_controls <- extend_back_linear(district_controls,var)
  }
  stopifnot(!anyNA(district_controls %>% filter(year<=2001)))
  return(district_controls)
}

get_rni_riots_iyer <- function(rni_district, district_parents, riots_goyal_clean, festival_iyer, riot_kernel, district_controls){
  # tar_load(rni_frozen_district); rni_district <- rni_frozen_district  # or rni_district (rni_annual)
  # tar_load(district_parents)
  # tar_load(riots_goyal_clean)
  # tar_load(festival_iyer)
  # tar_load(riot_kernel)
  # tar_load(district_controls)
  # One row per TCPD district and riot year t = 1970-1995; outcomes are births in t+1.
  # Timing follows Iyer: riot, instrument and bjprule in t; other controls in the outcome year.
  riots_parent <- riots_goyal_clean %>%
    zap_labels() %>%
    select(dist,year,riot,nriot,fridayfestival,fes)

  outcomes_lead <- rni_district %>%
    transmute(state,district,
              year=year-1,
              rni_Muslim_lead=rni_Muslim,
              rni_Hindu_lead=1-rni_Hindu,
              people_Muslim_lead=people_Muslim,
              people_Hindu_lead=people_Hindu)

  controls_lead <- district_controls %>%
    transmute(dist,year=year-1,muslim,urb,lit,ele,tap)

  rni_riots_iyer <- district_parents %>%
    select(state,district,district_id,dist,state_goyal,matched,parent_km) %>%
    cross_join(tibble(year=1970:1995)) %>%
    left_join(riots_parent,by=c("dist","year")) %>%
    # own-district riots are recorded only for districts on the 1981 list
    mutate(riot=if_else(matched,riot,0),
           nriot=if_else(matched,nriot,0)) %>%
    left_join(festival_iyer,by=c("state_goyal","year")) %>%
    left_join(riot_kernel,by=c("state","district","year")) %>%
    left_join(district_controls %>% select(dist,year,bjprule),by=c("dist","year")) %>%
    left_join(controls_lead,by=c("dist","year")) %>%
    inner_join(outcomes_lead,by=c("state","district","year")) %>%
    filter(!is.na(rni_Muslim_lead),!is.na(rni_Hindu_lead)) %>%
    mutate(time=year-1970,
           tsq=time^2,
           state_year=paste(state_goyal,year,sep="_"),
           people_lead=people_Muslim_lead+people_Hindu_lead)

  # fes_iyer reproduces Iyer's fes in every year Iyer has festival dates (1977-2001)
  overlap <- rni_riots_iyer %>% filter(!is.na(fes))
  stopifnot(nrow(overlap)>0,all(overlap$fes_iyer==overlap$fes))
  stopifnot(!anyDuplicated(rni_riots_iyer[c("district_id","year")]),
            !anyNA(rni_riots_iyer %>% select(riot,riotnear200,fes_iyer,fridayfestival,bjprule,muslim,tap)))
  return(rni_riots_iyer)
}
