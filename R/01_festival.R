
# Iyer & Shrivastava (2018) festival instrument ("fesfri" in "Tables 11, 12.do"):
# 1 if any of the state's three main Hindu festivals, Dushehra or Diwali falls on a Friday.
festival_lists_iyer <- list(
  andhrapradesh = c("ramnavami", "ashtami", "navami"),
  assam = c("janmashtami", "ashtami", "navami"),
  bihar = c("holi", "ramnavami", "navami"),
  gujarat = c("holi", "ramnavami", "navami"),
  haryana = c("holi", "shivratri", "janmashtami"),
  jammukashmir = c("shivratri", "janmashtami", "ramnavami"),
  karnataka = c("shivratri", "ganesh", "navami"),
  kerala = c("shivratri", "janmashtami", "navami"),
  maharashtra = c("navami", "ramnavami", "ganesh"),
  madhyapradesh = c("holi", "ramnavami", "janmashtami"),
  orissa = c("holi", "ashtami", "navami"),
  punjab = c("holi", "ramnavami", "janmashtami"),
  rajasthan = c("holi", "ramnavami", "janmashtami"),
  tamilnadu = c("janmashtami", "ganesh", "navami"),
  uttarpradesh = c("navami", "ramnavami", "janmashtami"),
  westbengal = c("holi", "ashtami", "navami")
)

get_festival_iyer <- function(riots_monthly_raw){
  # tar_load(riots_monthly_raw)

  # Goyal & van Noort's monthly file carries the festival dates and weekdays (1950-2006);
  # the dates are the same in every state, so keep one row per year
  festival_days <- riots_monthly_raw %>%
    zap_labels() %>%
    distinct(year,
             holi=holi_day,
             ramnavami=ramnavami_day,
             janmashtami=janamasthami_day,
             shivratri=shivratri_day,
             ganesh=ganeshcharturthi_day,
             navami=navami_day,
             ashtami=ashtami_day,
             dushehra=dushehra_day,
             diwali=diwali_day) %>%
    pivot_longer(-year,names_to="festival",values_to="weekday")
  stopifnot(!anyDuplicated(festival_days[c("year","festival")]))

  state_festivals <- tibble(state_goyal=names(festival_lists_iyer),
                            festival=festival_lists_iyer) %>%
    unnest(festival) %>%
    bind_rows(expand_grid(state_goyal=names(festival_lists_iyer),
                          festival=c("dushehra","diwali")))

  festival_iyer <- state_festivals %>%
    inner_join(festival_days,by="festival",relationship="many-to-many") %>%
    group_by(state_goyal,year) %>%
    summarise(fes_iyer=as.integer(any(weekday=="Friday")),
              fes_count=sum(weekday=="Friday"),
              .groups="drop")

  return(festival_iyer)
}
