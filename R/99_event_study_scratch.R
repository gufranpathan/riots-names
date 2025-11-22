last_riot_df <- rni_riots %>% 
  group_by(state,district) %>% 
  arrange(year) %>% 
  mutate(current_riot_year=if_else(riot==1,year,NA_integer_),
         current_riot_year_lag=lag(current_riot_year,1),
         last_riot_year=zoo::na.locf(current_riot_year_lag,na.rm=F),
         years_since_riot=last_riot_year - year)


last_riot_df %>% 
  select(state,district,year,riot,current_riot_year,current_riot_year_lag,last_riot) %>% 
  arrange(state,district) %>% 
  View()


event_study_data %>% 
  select(state,district,ever_riot,year,riot,years_since_riot,rni_Muslim_lead,riot_years) %>% 
  arrange(state,district) %>% 
  View()



tar_load(rni_riots)
rni_riots$riot
did_data <- rni_riots %>%
  # Create district ID (numeric)
  mutate(current_riot_year=if_else(riot==1,year,NA_integer_) ) %>% 
  group_by(state, district) %>%
  mutate(district_id = cur_group_id()) %>%
  ungroup() %>%
  # Determine first treatment year for each district
  group_by(district_id) %>%
  mutate(
    # First year with a riot
    first_riot_year = min(current_riot_year,na.rm=T),
    first_riot_year = replace_na(first_riot_year,0),
    # Binary: ever treated
    ever_treated = as.numeric(first_riot_year > 0),
    # Time since first treatment (negative before treatment)
    time_to_treatment = year - first_riot_year
  ) %>%
  ungroup() %>%
  # Rename for did package
  mutate(
    id = district_id,
    time = year,
    treat = ever_treated,
    g = first_riot_year  # Treatment cohort (0 = never treated)
  ) %>%
  # Keep relevant variables
  select(id, time, treat, g, riot, 
         rni_Muslim_lead, rni_Hindu_lead,
         state, district, district_id,
         people_Muslim, people_Hindu,
         KILLED, INJURED, nriot,
         first_riot_year, time_to_treatment)

analysis_data <- did_data %>%
  filter(!is.na(rni_Muslim_lead))


library(did)
att_muslim <- att_gt(
  yname = "rni_Muslim_lead",
  tname = "time",
  idname = "id",
  gname = "g",
  data = analysis_data,
  control_group = "nevertreated",
  anticipation = 0,
  base_period = "universal",
  clustervars = "id",
  est_method = "reg",  # regression-based
  print_details = TRUE
)

summary(att_muslim)

att_result <- att_muslim
# 1. Overall ATT (average across all treated groups and times)
agg_overall <- aggte(att_result, type = "simple")

# 2. Dynamic effects (event study by time relative to treatment)
agg_dynamic <- aggte(att_result, type = "dynamic")

# 3. Group-specific effects (by treatment cohort)
agg_group <- aggte(att_result, type = "group")

# 4. Calendar time effects
agg_calendar <- aggte(att_result, type = "calendar")

riot_frequency <- rni_riots %>% 
  group_by(state,district) %>% 
  summarize(riot_year=sum(riot))

hist(riot_frequency$riot_year)
summary(riot_frequency$riot_year)
round(table(riot_frequency$riot_year)/nrow(riot_frequency),2)*100
table(riot_frequency$riot_year)
cumsum(table(riot_frequency$riot_year))/nrow(riot_frequency)


source("_targets.R")
tar_load(rni_riots)
event_exp <- rni_riots %>% 
  mutate(current_riot_year=if_else(riot==1,year,NA_integer_),
         current_riot_year_lag=lag(current_riot_year,1),
         last_riot_year=zoo::na.locf(current_riot_year_lag,na.rm=F),
         years_since_riot=last_riot_year - year) %>% 
  group_by(state,district) %>% 
  mutate(ever_riot=max(riot))

never_riot <- event_exp %>% 
  filter(ever_riot==1)


library(ggplot2)

event_exp %>% 
  group_by(year,ever_riot) %>% 
  summarise(rni_Muslim_lead=mean(rni_Muslim_lead,na.rm=T)) %>% 
  ggplot(aes(x=year,y=rni_Muslim_lead,col=as.factor(ever_riot)))+
  geom_smooth()+
  theme_minimal()

riotted <- event_exp %>% 
  filter(ever_riot==1) %>% 
  group_by(years_since_riot) %>% 
  summarize(rni_Muslim_lead=mean(rni_Muslim_lead,na.rm=T))


ggplot(aes(x=years_since_riot,y=rni_Muslim_lead),data=riotted)+
  geom_line()


# One riot and control
source("_targets.R")
tar_load(rni_riots)

one_control <- rni_riots %>% 
  mutate(current_riot_year=if_else(riot==1,year,NA_integer_) ) %>% 
  group_by(state,district) %>% 
  mutate(riot_years=sum(riot),
         ever_riot=max(riot),
         district_id=cur_group_id(),
         first_riot_year = min(current_riot_year,na.rm=T),
         first_riot_year = if_else(first_riot_year==Inf,0,first_riot_year),
         first_riot_year = replace_na(first_riot_year,0)) %>% 
  filter(riot_years<=1)


# Create district ID (numeric)
one_control %>% 
  group_by(year,ever_riot) %>% 
  summarise(rni_Muslim_lead=mean(rni_Muslim_lead,na.rm=T)) %>% 
  ggplot(aes(x=year,y=rni_Muslim_lead,col=as.factor(ever_riot)))+
  geom_smooth()+
  theme_minimal()



att_muslim <- att_gt(
  yname = "rni_Muslim_lead",
  tname = "year",
  idname = "district_id",
  gname = "first_riot_year",
  data = one_control,
  control_group = "nevertreated",
  anticipation = 0,
  base_period = "universal",
  clustervars = "district_id",
  est_method = "reg",  # regression-based
  print_details = TRUE
)
att_result <- att_muslim
# 1. Overall ATT (average across all treated groups and times)
agg_overall <- aggte(att_result, type = "simple")

# 2. Dynamic effects (event study by time relative to treatment)
agg_dynamic <- aggte(att_result, type = "dynamic")

# 3. Group-specific effects (by treatment cohort)
agg_group <- aggte(att_result, type = "group")

# 4. Calendar time effects
agg_calendar <- aggte(att_result, type = "calendar")



library(fixest)
summary(feols(rni_Muslim_lead ~ riot | district,data=rni_riots))
summary(feols(rni_Muslim_lead ~ 1 | district | riot ~ fridayfestival,data=rni_riots))

ggplot(aes(x=rni_Muslim_lead,col=as.factor(riot)),data=rni_riots)+
  geom_density()

ggplot(aes(x=rni_Hindu_lead,col=as.factor(riot)),data=rni_riots)+
  geom_density()

ggplot(aes(x=rni_Muslim_lead,col=as.factor(riot)),data=rni_riots)+
  geom_density()


rni_riots$fitted_riot <- fitted(muslim_model$iv_first_stage$riot)

table(rni_riots$fitted_riot,rni_riots$riot)
table(rni_riots$fitted_riot,rni_riots$fridayfestival)

ggplot(aes(x=rni_Muslim_lead,col=as.factor(fitted_riot)),data=rni_riots)+
  geom_density()

tar_load(iv_models)

muslim_mod$el <- iv_models[['muslim_models']][[1]]


fitted(muslim_model)
