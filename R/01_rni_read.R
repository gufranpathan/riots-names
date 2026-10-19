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
                            "jammuandkashmir"~"jammukashmir",
                            "skiim"~"sikkim",
                            "uttrakhand"~"uttarakhand",
                            .default=state)) %>%
    # The AP file uses post-2014 AC numbers (1-175); TCPD Delim4 numbers undivided AP
    # (Telangana 1-119, the rest 120-294), e.g. Ichchapuram is AP AC 1 and TCPD AC 120.
    mutate(assembly_no=if_else(state=="andhrapradesh",assembly_no+119,assembly_no)) %>%
    # Telangana keeps ACs 1-119; it was part of AP (and its festival list) until 2014
    mutate(state=if_else(state=="telangana","andhrapradesh",state)) %>%
    filter(state!="odisha") %>% # Removing Odisha because unusually large count of voters
    inner_join(ac_delim,by=c("state","assembly_no"="AC_No")) %>%
    filter(!AC_Name%in%c("ALGAPUR","HAFLONG")) %>%   # unusually low number of voters
    filter(year>=1950,year<=1996) # 1996 births are the t+1 outcome for riot year 1995
    
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
    filter(!is.na(rni_Muslim_lead),!is.na(rni_Hindu_lead),!is.na(riot),!is.na(fridayfestival)) %>%
    filter(year<=1994) # original sample; rni_clean now runs to 1996 for rni_riots_iyer_annual
  return(rni_riots)
}

# ============================================================================
# Frozen RNI (data/0_raw/segregation data 2026): every name keeps the score it had among
# people born before 1970; births 1971-1997
# ============================================================================

get_rni_frozen_annual_raw <- function(rni_frozen_path){
  # tar_load(rni_frozen_path)
  # Booth-level file (35 million rows): religion x AC x birth year x polling booth, with the
  # number of voters (count) and their mean frozen RNI (mean_rni, missing when no voter in the
  # cell has a scored name). Aggregated to AC x birth year x religion in the layout of
  # rni_annual_raw: index_avg_pn is the voter-weighted mean RNI over booths with a score and
  # sample_size the number of voters in those booths.
  booth_schema <- schema(religion=utf8(),state=utf8(),ac_id_fn=utf8(),birth_year_clean=float64(),
                         part_no_fn=utf8(),count=float64(),mean_rni=float64())
  rni_frozen_annual_raw <- open_dataset(rni_frozen_path,format="csv",schema=booth_schema,skip=1,
                                        convert_options=CsvConvertOptions$create(null_values=c("NA",""),strings_can_be_null=TRUE)) %>% 
    mutate(scored=!is.na(mean_rni),
           count_scored=if_else(scored,count,0),
           rni_x_count=if_else(scored,mean_rni*count,0)) %>% 
    group_by(state,ac_id_fn,birth_year_clean,religion) %>% 
    summarise(booths=n(),
              booths_scored=sum(scored),
              people_total=sum(count),
              sample_size=sum(count_scored),
              rni_x_count=sum(rni_x_count)) %>% 
    collect() %>% 
    ungroup() %>% 
    mutate(index_avg_pn=if_else(sample_size>0,rni_x_count/sample_size,NA_real_)) %>% 
    select(-rni_x_count)
  return(rni_frozen_annual_raw)
}

get_rni_frozen_clean <- function(rni_frozen_annual_raw, ac_delim){
  # tar_load(rni_frozen_annual_raw)
  # tar_load(ac_delim)
  # Same cleaning as rni_clean (AP numbering, Telangana as AP, Odisha dropped). Odisha is
  # also unusable here: some ACs repeat the same voters several times (up to 90,139 births
  # in one AC-year against a state median of 3,285), and the frozen index barely separates
  # Muslims (median 0.43) from Hindus (0.35) there.
  rni_frozen_clean <- get_rni_clean(rni_frozen_annual_raw %>% filter(sample_size>0),ac_delim)
  return(rni_frozen_clean)
}

get_rni_frozen_district <- function(rni_frozen_clean){
  # tar_load(rni_frozen_clean)
  rni_frozen_district <- get_rni_district(rni_frozen_clean)
  return(rni_frozen_district)
}

get_rni_frozen_coverage <- function(rni_frozen_annual_raw, rni_frozen_clean){
  # tar_load(rni_frozen_annual_raw)
  # tar_load(rni_frozen_clean)
  # Coverage of the frozen RNI by state, births 1971-1996
  path_tracking_vector <- c()
  output_path <- "data/02_output/frozen_rni/"
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  ac_years <- rni_frozen_annual_raw %>% 
    filter(birth_year_clean<=1996) %>% 
    group_by(state,ac_id_fn,birth_year_clean) %>% 
    summarise(people=sum(people_total),.groups="drop") %>% 
    group_by(state) %>% 
    summarise(acs=n_distinct(ac_id_fn),
              median_people_per_ac_year=median(people),
              max_people_per_ac_year=max(people))
  rni_frozen_coverage <- rni_frozen_annual_raw %>% 
    filter(birth_year_clean<=1996) %>% 
    group_by(state) %>% 
    summarise(prefix=first(str_split_i(ac_id_fn,"_",1)),
              people=sum(people_total),
              share_people_scored=sum(sample_size)/sum(people_total),
              muslim_share=sum(people_total[religion=="Muslim"])/sum(people_total),
              rni_muslims=weighted.mean(index_avg_pn[religion=="Muslim"],sample_size[religion=="Muslim"],na.rm=TRUE),
              rni_hindus=weighted.mean(index_avg_pn[religion=="Hindu"],sample_size[religion=="Hindu"],na.rm=TRUE)) %>% 
    left_join(ac_years,by="state") %>% 
    mutate(in_clean_data=str_to_lower(prefix)%in%unique(str_to_lower(str_split_i(rni_frozen_clean$ac_id_fn,"_",1)))) %>% 
    arrange(desc(people))
  save_track_object(rni_frozen_coverage,write.csv,output_extension="csv",output_path=output_path,row.names=FALSE)
  return(path_tracking_vector)
}
