library(arrow)

seg <- read_parquet("data/0_raw/12-segregation/state_dir=Bihar/segregation_Bihar.0.parquet")
View(head(seg))
unique(seg$religion)
seg %>% filter(religion=="Hindu") %>% head(100)

read.csv("da")

library(haven)

dataset_main <- read_dta("data/0_raw/01-riots/iyer/Replication/dataset_main.dta")

dataset_main %>% 
  group_by(year,fes) %>% 
  summarise() %>% 
  group_by(year) %>% 
  mutate(years=n()) %>% 
  filter(years>1) %>% 
  View()

goyal <- read_dta("data/0_raw/01-riots/sj-zip-2-jcr-10.1177_00220027251383563/Final ethnic riots data.dta")
distict_raw <- read.csv("data/0_raw/12-delim4/TCPD_AC_PC_Mapping_Delim4.csv")

districts <- distict_raw %>% 
  filter(DelimID==4) %>% 
  mutate(district=str_remove_all(str_to_lower(District_Name)," "),
         state=str_to_lower(str_remove_all(State_Name,"_|\\&"))) %>% 
  group_by(state,district) %>% 
  summarize() %>% 
  ungroup() 

riots <- goyal %>% 
  mutate(state=case_match(state,
    "orissa"~"odisha",
    .default = state
  ))

dis_states <- unique(districts$state)
goy_states <- unique(riots$state)

goy_states[!goy_states%in%dis_states]

unmatched_dists <-riots %>%
  mutate(in_riots=1) %>% 
  left_join(districts %>% mutate(in_tcpd=1) ,by = c("state","district")) %>% 
  filter(is.na(in_tcpd)) %>% 
  group_by(state,district) %>% 
  summarize()
# unmatched_dists %>% clipr::write_clip()


riots_districts <- riots %>% 
  group_by(state,district) %>% 
  summarize()
riots_districts %>% clipr::write_clip()



# Clean Districts ----
library(readxl)
district_corrections <- read_excel("data/0_raw/01-riots/riots_tcpd_district_mapping.xlsx")
riots <- goyal %>% 
  mutate(state=case_match(state,
                          "orissa"~"odisha",
                          .default = state
  )) %>% 
  left_join(district_corrections,by=c("state","district")) %>% 
  mutate(state=coalesce(state_tcpd,state),
         district=coalesce(district_tcpd,district))

unmatched_dists <-riots %>%
  mutate(in_riots=1) %>% 
  left_join(districts %>% mutate(in_tcpd=1) ,by = c("state","district")) %>% 
  filter(is.na(in_tcpd)) %>% 
  group_by(state,district) %>% 
  summarize()


# Join RNI and Riots ----

tar_load(riots_goyal_clean)
tar_load(rni_district)

colnames(riots_goyal_clean)
colnames(rni_district)

unique(rni_district$state)
unique(riots_goyal_clean$state)

state_district <- rni_district %>% 
  group

unique(as.integer(rni_district$year))
rni_riots <- rni_district %>% 
  filter(state%in%riots_goyal_clean$state) %>% 
  left_join(riots_goyal_clean,by=c("state","district","year"),suffix = c("_rni","_riots")) %>% 
  mutate(riot=replace_na(riot,0),
         nriot=replace_na(riot,0),
         KILLED=replace_na(KILLED,0),
         INJURED=replace_na(INJURED,0),
         ARRESTS=replace_na(ARRESTS,0))


all_districts_rni <- rni_district %>% 
  group_by(state,district) %>% 
  summarise(years=n())

nrow(all_districts_rni)

# 509 districts, 46 years
table(all_districts_rni$years)
summary(rni_district$year)
tar_load(riots_goyal_clean)


all_districts_riots <- riots_goyal_clean %>% 
  group_by(state,district) %>% 
  summarise(years=n())

nrow(all_districts_riots)
table(all_districts_riots$years)
summary(riots_goyal_clean$year)

riots_goyal_clean %>% 
  group_by(year) %>% 
  summarize(riots=mean(riot),fridayfestival=mean(fridayfestival)) %>% 
  ggplot(aes(x=year))+
  geom_line(aes(y=riots))+
  geom_line(aes(y=fridayfestival))+
  theme_minimal()
