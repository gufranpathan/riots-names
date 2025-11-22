# 1. Load the library
library(fixest)
source("_targets.R")
tar_load(rni_riots)
tar_load(riots_goyal_clean)

colnames(riots_goyal_clean)


riots_goyal_clean %>%
  group_by(state,district,year,muslim_pop) %>% 
  View()


riots_goyal_clean %>% 
  group_by(year,fridayfestival) %>% 
  summarize(obs=n()) %>% 
  group_by(year) %>% 
  mutate(years=n()) %>% 
  filter(years>1) %>% 
  View()

# 2. Define your set of control variables
# (You can adjust this list as needed)
my_controls <- c("muslim_pop", "urban_pop", "perc_literate", 
                 "perc_electricity", "bjprule", "incrule")

# 3. Create the model formula
# We use paste() to keep the final feols() call clean
iv_formula <- as.formula(
  paste("rni_Muslim_lead ~", paste(my_controls, collapse = " + "),
        "| district + year |", # Part 2: Fixed Effects
        "riot ~ fridayfestival")   # Part 3: IV (Endogenous ~ Instrument)
)

# The formula will look like this:
# rni_Muslim_lead ~ muslim_pop + ... + incrule | district + year | riot ~ fridayfestival

# 4. Run the IV estimation
# Assumes your data is named 'rni_riots'
model_iv <- feols(iv_formula, data = rni_riots)

model_iv <- feols(rni_Muslim_lead ~ 1 | district | riot ~ fridayfestival, data = rni_riots %>% filter(year>=1970, year<1980))
summary(model_iv)

model1 <- feols(rni_Muslim_lead ~ 1 | riot ~ fridayfestival, data = rni_riots, vcov = "hetero")
summary(model1)

model2 <- feols(rni_Muslim_lead ~ 1 | district | riot ~ fridayfestival, data = rni_riots, vcov = "hetero")
summary(model2)

model_iv <- feols(rni_Muslim_lead ~ year | district | riot ~ fridayfestival, data = rni_riots, vcov = "hetero")
summary(model_iv)

model_iv <- feols(rni_Muslim_lead ~ 1 | district + year | riot ~ fridayfestival, data = rni_riots, vcov = "hetero")
summary(model_iv)

summary(lm(fridayfestival~year_base,data=rni_riots %>% mutate(year_base=year-1950)))

model_iv <- feols(rni_Muslim_lead ~ year | riot ~ fridayfestival, data = rni_riots)
summary(model_iv)


model_iv <- feols(rni_Hindu_lead ~ 1 | district | riot ~ fridayfestival, data = rni_riots)
summary(model_iv)


# where should we expect stronger results? (more casuality)
# mitigating riots (some mitigation)? state capacity, civic / social ties, party compeition / bjp role /segregation?
# are these localized?
# create a more local identifier dataset


rni_riots %>% filter(is.na(rni_Muslim_lead))

nrow(rni_riots)

rni_riots %>% 
  filter(is.na(fridayfestival)) %>% 
  group_by(state,district) %>% 
  summarize(obs=n()) %>% 
  View()

sum(is.na(rni_riots$fridayfestival))

# 5. View the summary of the results
summary(model_iv)


model_iv <- feols(rni_Muslim_lead ~ muslim_pop + urban_pop + perc_literate + perc_electricity + 
                    bjprule + incrule | district + year | riot ~ fridayfestival, data = rni_riots)

summary(model_iv)


tar_load(rni_riots)
View(head(rni_riots))


table(rni_riots$fridayfestival,useNA = 'always')



table(riots_goyal_clean$year)
nrow(riots_goyal_clean)
riots_goyal_clean %>% 
  group_by(state,district,year) %>% 
  summarize(obs=n()) %>% 
  filter(obs>1) %>% 
  pull(district) %>% 
  unique()


library(ggplot2)
rni_riots$fridayfestival
ggplot(aes(x=rni_Muslim_lead,col=as.factor(fridayfestival)),data=rni_riots)+
  geom_density()

ggplot(aes(x=rni_Hindu_lead,col=as.factor(fridayfestival)),data=rni_riots)+
  geom_density()


rni_riots %>% 
  group_by(state) %>% 
  summarize(fridayfestivals=mean(fridayfestival)) %>% 
  arrange(fridayfestivals)


rni_riots %>% 
  group_by(state,year) %>% 
  summarize(fridayfestival=mean(fridayfestival)) %>% 
  ggplot(aes(x=year,y=fridayfestival))+
  geom_col()+
  facet_wrap(~state)

