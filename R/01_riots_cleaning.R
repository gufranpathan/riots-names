

get_riots_annual <- function(riots_raw){
  # tar_load(riots_raw)
  # colnames(riots_raw) <- str_to_lower(colnames(riots_raw))
  riots_annual <- riots_raw %>% 
    group_by(year,state,statecode,district,town_city,village) %>% 
    summarise(killed=sum(killed),
              injured=sum(injured),
              arrests=sum(arrests)) %>% 
    mutate(killed=replace_na(killed,0),
           injured=replace_na(injured,0),
           arrests=replace_na(arrests,0)) %>% 
    mutate(is_urban=(town_city!=""),
           town_city_village=if_else(is_urban,town_city,village))
  
  return(riots_annual)
    
}

get_riots_location <- function(riots_annual){
  riots_location <- riots_annual %>% 
    group_by(state,statecode,district,town_city,village,is_urban,town_city_village) %>% 
    summarise(killed=sum(killed),
              injured=sum(injured),
              arrests=sum(arrests)) %>% 
    mutate(killed=replace_na(killed,0),
           injured=replace_na(injured,0),
           arrests=replace_na(arrests,0)) %>% 
    mutate(is_urban=(town_city!=""),
           town_city_village=if_else(is_urban,town_city,village))
  
  return(riots_location)
  
}

get_riots_goyal_clean <- function(riots_goyal_raw, district_corrections){
  riots_goyal_clean <- riots_goyal_raw %>%
    mutate(state_goyal=state) %>% # pre-2000 state; sets the festival list of the instrument
    mutate(state=case_match(state,
                            "orissa"~"odisha",
                            .default = state
    )) %>%
    left_join(district_corrections,by=c("state","district")) %>%
    # The mapping file sends kanpur to uttarakhand/nainital. That duplicated nainital, and the
    # old fix dropped both districts. Kanpur (1981) is TCPD kanpurnagar plus kanpurgrameen.
    mutate(state_tcpd=if_else(district=="kanpur","uttarpradesh",state_tcpd),
           district_tcpd=if_else(district=="kanpur","kanpurnagar",district_tcpd)) %>%
    mutate(state=coalesce(state_tcpd,state),
           district=coalesce(district_tcpd,district))
  stopifnot(!anyDuplicated(riots_goyal_clean[c("state","district","year")]))
  return(riots_goyal_clean)

}

get_friday_festival <- function(riots_goyal_clean){
  # tar_load(riots_goyal_clean)
  
  friday_festival <- riots_goyal_clean %>% 
    group_by(state,year,fridayfestival) %>% 
    summarize()
  
  return(friday_festival)
}