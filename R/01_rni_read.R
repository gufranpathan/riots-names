get_rni_parquet_paths <- function(){
  return(list.files("data/0_raw/12-segregation/",recursive = TRUE,pattern="*.parquet",full.names = T))
}

get_rni_annual_paths <- function(){
  return(list.files("data/0_raw/rni_annual/ac_year/",recursive = TRUE,pattern="*.csv",full.names = T))
}



get_rni_raw <- function(rni_parquet_paths){
  # tar_load(rni_parquet_paths)
  rni_raw <- open_dataset(rni_parquet_paths) %>% collect()
  return(rni_raw)
}


get_rni_annual_raw <- function(rni_annual_paths){
  # tar_load(rni_annual_paths)
  rni_annual_raw_list <- vector(mode='list',length=length(rni_annual_paths))
  for(i in 1:length(rni_annual_paths)){
    state_rni <- read.csv(rni_annual_paths[i])
    rni_annual_raw_list[[i]] <- state_rni
  }
  rni_annual_raw <- bind_rows(rni_annual_raw_list)
  return(rni_annual_raw)
}



get_rni_clean <- function(rni_annual_raw, ac_delim){
  # tar_load(rni_annual_raw)
  # tar_load(ac_delim)
  rni_clean <- rni_annual_raw %>% 
    rename(year=birth_year_clean) %>% 
    mutate(state=str_to_lower(str_split_i(ac_id_fn,"_",1)),
           assembly_no=as.numeric(str_split_i(ac_id_fn,"_",2))) %>% 
    mutate(state=case_match(state,
                            "madhyapradhesh"~"madhyapradesh",
                            "jammuandkashmir"~"maharashtra",
                            "skiim"~"sikkim",
                            "uttrakhand"~"uttarakhand",
                            .default=state)) %>% 
    filter(state!="odisha") %>% # Removing Odisha because unusually large count of voters 
    inner_join(ac_delim,by=c("state","assembly_no"="AC_No")) %>% 
    filter(!AC_Name%in%c("ALGAPUR","HAFLONG")) %>%   # unusually low number of voters
    filter(year>=1950,year<=1995)
    
  return(rni_clean)

}

get_rni_ac <- function(rni_clean){
  # tar_load(rni_clean)
  # colnames(rni_clean)
  rni_ac <- rni_clean %>% 
    filter(!religion%in%c("Christian","Others")) %>% 
    mutate(religion=if_else(religion=="Muslim","Muslim","Hindu")) %>% 
    group_by(year,state,assembly_no,AC_Name,district,Sub_Region, PC_No,PC_Name,religion) %>% 
    summarise(people=sum(sample_size,na.rm=T),
              rni=weighted.mean(index_avg_pn,sample_size)) %>% 
    ungroup()  %>% 
    pivot_wider(names_from=religion,values_from=c(people,rni))
  return(rni_ac)
}

get_rni_district <- function(rni_clean){
  # tar_load(rni_clean)
  # colnames(rni_clean)
  rni_district <- rni_clean %>% 
    filter(!religion%in%c("Christian","Others")) %>% 
    mutate(religion=if_else(religion=="Muslim","Muslim","Hindu")) %>% 
    group_by(state,year,district,religion) %>% 
    summarise(people=sum(sample_size,na.rm=T),
              rni=weighted.mean(index_avg_pn,sample_size)) %>% 
    ungroup()  %>% 
    pivot_wider(names_from=religion,values_from=c(people,rni))
  return(rni_district)
  
}

get_rni_riots <- function(rni_district,riots_goyal_clean,friday_festival){
  # tar_load(rni_district)
  # tar_load(riots_goyal_clean)
  # tar_load(friday_festival)
  
  rni_riots <- rni_district %>% 
    filter(state%in%riots_goyal_clean$state) %>% 
    left_join(riots_goyal_clean,by=c("state","district","year"),suffix = c("_rni","_riots")) %>% 
    select(-fridayfestival) %>% 
    left_join(friday_festival,by=c("state","year")) %>% 
    mutate(riot=replace_na(riot,0),
           nriot=replace_na(nriot,0),
           KILLED=replace_na(KILLED,0),
           INJURED=replace_na(INJURED,0),
           ARRESTS=replace_na(ARRESTS,0)) %>% 
    group_by(state, district) %>% 
    arrange(year) %>% 
    mutate(riot_lag=lag(riot),
           nriot_lag=lag(nriot),
           KILLED_lag=lag(KILLED),
           INJUREDlag=lag(INJURED),
           ARRESTSlag=lag(ARRESTS),
           rni_Muslim_lead=lead(rni_Muslim),
           rni_Hindu_lead=lead(rni_Hindu),
           ever_riot=max(riot),
           riot_year=sum(riot)) %>% 
    mutate(rni_Hindu_lead=(1-rni_Hindu_lead),
           rni_Hindu = (1 - rni_Hindu)) %>% 
    filter(!is.na(rni_Muslim_lead),!is.na(rni_Hindu_lead),!is.na(riot),!is.na(fridayfestival))
  return(rni_riots)
}