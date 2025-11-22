summary(feols(rni_Muslim_lead ~ riot, data=rni_riots))

summary(feols(rni_Muslim_lead ~ fridayfestival, data=rni_riots))

summary(feols(riot ~ fridayfestival, data=rni_riots))

summary(feols(rni_Muslim_lead ~ 1  | riot ~ fridayfestival, data=rni_riots))

summary(feols(rni_Muslim_lead ~ fitted_riot, data=rni_riots))


# ============================================================================
# Event Study Analysis: RNI Around Riot Events
# ============================================================================

#' Prepare event study data with leads and lags
#' 
#' @param rni_riots Dataset with district-year panel
#' @param max_lag Maximum years before riot to include
#' @param max_lead Maximum years after riot to include
#' @return Dataset with event time variables
get_event_study_data <- function(rni_riots, max_lag = 3, max_lead = 3) {
  # tar_load(rni_riots)
  library(tidyverse)
  
  event_study_data <- rni_riots %>%
    arrange(state, district, year) %>%
    group_by(state, district) %>%
    mutate(
      # Create indicators for riot occurrence in surrounding years
      riot_lag1 = lag(riot, 1),
      riot_lag2 = lag(riot, 2),
      riot_lag3 = lag(riot, 3),
      riot_lead1 = lead(riot, 1),
      riot_lead2 = lead(riot, 2),
      riot_lead3 = lead(riot, 3),
      
      # Create event time variable (years since/until riot)
      # This will be used for districts that ever experience a riot
      ever_riot = max(riot, na.rm = TRUE),
      
      # For each year, calculate years since most recent riot
      years_since_riot = NA_integer_
    ) %>%
    ungroup()
  
  # Calculate years since riot for each observation
  event_study_data <- event_study_data %>%
    group_by(state, district) %>%
    arrange(year) %>%
    mutate(
      # Find all riot years for this district
      riot_years = list(year[riot == 1]),
      # For each observation, find time to nearest riot
      years_since_riot = map2_dbl(year, riot_years, function(y, riot_yrs) {
        if (length(riot_yrs) == 0) return(NA_real_)
        diffs <- y - riot_yrs
        # Return the smallest absolute difference, with sign
        closest <- diffs[which.min(abs(diffs))]
        return(closest)
      })
    ) %>%
    select(-riot_years) %>%
    ungroup()
  
  # Create event time categories
  event_study_data <- event_study_data %>%
    mutate(
      event_time = case_when(
        is.na(years_since_riot) ~ "Never Riot",
        years_since_riot < -max_lag ~ paste0("< -", max_lag),
        years_since_riot > max_lead ~ paste0("> +", max_lead),
        TRUE ~ as.character(years_since_riot)
      ),
      event_time_numeric = ifelse(event_time == "Never Riot", NA_real_, 
                                  years_since_riot),
      # Create binned event time for regression
      event_time_binned = case_when(
        event_time == "Never Riot" ~ "Never Riot",
        years_since_riot <= -max_lag ~ paste0("≤ -", max_lag),
        years_since_riot >= max_lead ~ paste0("≥ +", max_lead),
        TRUE ~ as.character(years_since_riot)
      )
    )
  
  return(event_study_data)
}


#' Calculate mean RNI by event time
#' 
#' @param event_study_data Output from get_event_study_data
#' @return Aggregated data for plotting
get_event_study_summary <- function(event_study_data) {
  # tar_load(event_study_data)
  library(tidyverse)
  
  # Calculate means by event time for ever-riot districts
  summary_ever_riot <- event_study_data %>%
    filter(ever_riot == 1, !is.na(event_time_numeric)) %>%
    group_by(event_time_numeric) %>%
    summarise(
      rni_Muslim = mean(rni_Muslim_lead, na.rm = TRUE),
      rni_Hindu = mean(rni_Hindu_lead, na.rm = TRUE),
      se_Muslim = sd(rni_Muslim_lead, na.rm = TRUE) / sqrt(n()),
      se_Hindu = sd(rni_Hindu_lead, na.rm = TRUE) / sqrt(n()),
      n_obs = n(),
      .groups = "drop"
    ) %>%
    mutate(group = "Ever Riot Districts")
  
  # Calculate means for never-riot districts (constant over time)
  summary_never_riot <- event_study_data %>%
    filter(ever_riot == 0) %>%
    summarise(
      rni_Muslim = mean(rni_Muslim_lead, na.rm = TRUE),
      rni_Hindu = mean(rni_Hindu_lead, na.rm = TRUE),
      se_Muslim = sd(rni_Muslim_lead, na.rm = TRUE) / sqrt(n()),
      se_Hindu = sd(rni_Hindu_lead, na.rm = TRUE) / sqrt(n()),
      n_obs = n()
    ) %>%
    mutate(group = "Never Riot Districts")
  
  # Combine for plotting
  event_study_summary <- list(
    ever_riot = summary_ever_riot,
    never_riot = summary_never_riot
  )
  
  return(event_study_summary)
}


#' Create event study plot
#' 
#' @param event_study_summary Output from get_event_study_summary
#' @param religion Either "Muslim" or "Hindu"
#' @return ggplot object
plot_event_study <- function(event_study_summary, religion = "Muslim") {
  # tar_load(event_study_summary)
  library(ggplot2)
  library(tidyverse)
  
  rni_var <- paste0("rni_", religion)
  se_var <- paste0("se_", religion)
  
  # Prepare data for plotting
  plot_data <- event_study_summary$ever_riot %>%
    select(event_time = event_time_numeric, 
           rni = all_of(rni_var),
           se = all_of(se_var))
  
  # Add never-riot reference line
  never_riot_mean <- event_study_summary$never_riot[[rni_var]]
  never_riot_se <- event_study_summary$never_riot[[se_var]]
  
  # Create plot
  p <- ggplot(plot_data, aes(x = event_time, y = rni)) +
    # Add never-riot reference line
    geom_hline(yintercept = never_riot_mean, 
               linetype = "dashed", 
               color = "gray50",
               linewidth = 0.8) +
    geom_ribbon(aes(ymin = never_riot_mean - 1.96 * never_riot_se,
                    ymax = never_riot_mean + 1.96 * never_riot_se),
                fill = "gray70", alpha = 0.3) +
    # Add confidence interval for ever-riot districts
    geom_ribbon(aes(ymin = rni - 1.96 * se, 
                    ymax = rni + 1.96 * se),
                fill = "steelblue", alpha = 0.3) +
    # Add line and points
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(color = "steelblue", size = 3) +
    # Mark riot occurrence at t=0
    geom_vline(xintercept = 0, linetype = "dotted", 
               color = "red", linewidth = 0.8) +
    # Labels and theme
    labs(
      x = "Years Relative to Riot",
      y = paste(religion, "Name Index"),
      title = paste("Event Study:", religion, "Name Distinctiveness Around Riots"),
      subtitle = "Solid line: Districts that experienced riots | Dashed line: Districts without riots",
      caption = "Note: Riot occurs at t=0. Confidence intervals show ±1.96 SE. Standard errors not clustered."
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10, color = "gray40"),
      panel.grid.minor = element_blank(),
      axis.title = element_text(size = 11)
    ) +
    scale_x_continuous(breaks = seq(-3, 3, 1))
  
  return(p)
}


#' Create combined event study plot (both religions)
#' 
#' @param event_study_summary Output from get_event_study_summary
#' @return ggplot object with facets
plot_event_study_combined <- function(event_study_summary) {
  # tar_load(event_study_summary)
  library(ggplot2)
  library(tidyverse)
  
  # Prepare data for both religions
  plot_data <- event_study_summary$ever_riot %>%
    select(event_time = event_time_numeric, 
           rni_Muslim, se_Muslim,
           rni_Hindu, se_Hindu) %>%
    pivot_longer(
      cols = c(rni_Muslim, rni_Hindu),
      names_to = "religion",
      names_prefix = "rni_",
      values_to = "rni"
    ) %>%
    mutate(
      se = ifelse(religion == "Muslim", se_Muslim, se_Hindu)
    ) %>%
    select(event_time, religion, rni, se)
  
  # Never-riot reference
  never_riot_data <- event_study_summary$never_riot %>%
    select(rni_Muslim, se_Muslim, rni_Hindu, se_Hindu) %>%
    pivot_longer(
      cols = c(rni_Muslim, rni_Hindu),
      names_to = "religion",
      names_prefix = "rni_",
      values_to = "never_riot_mean"
    ) %>%
    mutate(
      never_riot_se = ifelse(religion == "Muslim", se_Muslim, se_Hindu)
    ) %>%
    select(religion, never_riot_mean, never_riot_se)
  
  # Join
  plot_data <- plot_data %>%
    left_join(never_riot_data, by = "religion")
  
  # Create plot
  p <- ggplot(plot_data, aes(x = event_time, y = rni)) +
    # Add never-riot reference line
    geom_hline(aes(yintercept = never_riot_mean), 
               linetype = "dashed", 
               color = "gray50",
               linewidth = 0.8) +
    geom_ribbon(aes(ymin = never_riot_mean - 1.96 * never_riot_se,
                    ymax = never_riot_mean + 1.96 * never_riot_se),
                fill = "gray70", alpha = 0.3) +
    # Add confidence interval for ever-riot districts
    geom_ribbon(aes(ymin = rni - 1.96 * se, 
                    ymax = rni + 1.96 * se),
                fill = "steelblue", alpha = 0.3) +
    # Add line and points
    geom_line(color = "steelblue", linewidth = 1) +
    geom_point(color = "steelblue", size = 3) +
    # Mark riot occurrence at t=0
    geom_vline(xintercept = 0, linetype = "dotted", 
               color = "red", linewidth = 0.8) +
    # Facet by religion
    facet_wrap(~religion, ncol = 2, scales = "free_y") +
    # Labels and theme
    labs(
      x = "Years Relative to Riot",
      y = "Name Index",
      title = "Event Study: Name Distinctiveness Around Riots",
      subtitle = "Solid line: Districts that experienced riots | Dashed line: Districts without riots",
      caption = "Note: Riot occurs at t=0. Confidence intervals show ±1.96 SE."
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10, color = "gray40"),
      panel.grid.minor = element_blank(),
      axis.title = element_text(size = 11),
      strip.text = element_text(face = "bold", size = 12)
    ) +
    scale_x_continuous(breaks = seq(-3, 3, 1))
  
  return(p)
}


#' Run event study regression with event time dummies
#' 
#' @param event_study_data Output from get_event_study_data
#' @param outcome Either "rni_Muslim" or "rni_Hindu"
#' @return fixest model object
run_event_study_regression <- function(event_study_data, outcome = "rni_Muslim") {
  # tar_load(event_study_data)
  library(fixest)
  library(tidyverse)
  
  # Prepare data: only districts that ever had a riot
  reg_data <- event_study_data %>%
    filter(ever_riot == 1, !is.na(event_time_numeric)) %>%
    # Create dummy variables for each event time
    mutate(
      # Reference period is t = -1 (year before riot)
      t_minus3 = ifelse(years_since_riot <= -3, 1, 0),
      t_minus2 = ifelse(years_since_riot == -2, 1, 0),
      # t_minus1 is reference (omitted)
      t_0 = ifelse(years_since_riot == 0, 1, 0),
      t_plus1 = ifelse(years_since_riot == 1, 1, 0),
      t_plus2 = ifelse(years_since_riot == 2, 1, 0),
      t_plus3 = ifelse(years_since_riot >= 3, 1, 0)
    )
  
  # Run regression with district FE
  formula_str <- paste0(
    outcome, 
    " ~ t_minus3 + t_minus2 + t_0 + t_plus1 + t_plus2 + t_plus3 | district"
  )
  
  model <- feols(
    as.formula(formula_str),
    data = reg_data,
    cluster = "district"
  )
  
  return(model)
}


#' Create coefficient plot from event study regression
#' 
#' @param model Event study regression model
#' @param religion Either "Muslim" or "Hindu" (for labeling)
#' @return ggplot object
plot_event_study_coefs <- function(model, religion = "Muslim") {
  # Extract coefficients and standard errors
  library(fixest)
  library(tidyverse)
  
  coef_data <- tibble(
    event_time = c(-3, -2, -1, 0, 1, 2, 3),
    coef = c(
      coef(model)["t_minus3"],
      coef(model)["t_minus2"],
      0,  # Reference period
      coef(model)["t_0"],
      coef(model)["t_plus1"],
      coef(model)["t_plus2"],
      coef(model)["t_plus3"]
    ),
    se = c(
      se(model)["t_minus3"],
      se(model)["t_minus2"],
      0,  # Reference period
      se(model)["t_0"],
      se(model)["t_plus1"],
      se(model)["t_plus2"],
      se(model)["t_plus3"]
    )
  ) %>%
    mutate(
      ci_lower = coef - 1.96 * se,
      ci_upper = coef + 1.96 * se
    )
  
  # Create plot
  p <- ggplot(coef_data, aes(x = event_time, y = coef)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_vline(xintercept = -0.5, linetype = "dotted", color = "red") +
    geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper), 
                  width = 0.2, linewidth = 0.8,
                  color = "steelblue") +
    geom_point(size = 3, color = "steelblue") +
    geom_line(linewidth = 0.5, color = "steelblue") +
    labs(
      x = "Years Relative to Riot",
      y = paste("Effect on", religion, "Name Index"),
      title = paste("Event Study Regression:", religion, "Naming Response to Riots"),
      subtitle = "Reference period: t = -1 (year before riot) | With district fixed effects",
      caption = "Note: Error bars show 95% confidence intervals. Standard errors clustered at district level."
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10, color = "gray40"),
      panel.grid.minor = element_blank()
    ) +
    scale_x_continuous(breaks = -3:3)
  
  return(p)
}


#' Test for pre-trends
#' 
#' @param model Event study regression model
#' @return List with test statistics and p-value
test_pretrends <- function(model) {
  library(fixest)
  
  # Test if pre-period coefficients (t-3, t-2) are jointly zero
  # Note: t-1 is the reference period
  test_result <- wald(model, c("t_minus3 = 0", "t_minus2 = 0"))
  
  result <- list(
    statistic = test_result$stat,
    p_value = test_result$p,
    reject_null = test_result$p < 0.05,
    interpretation = ifelse(
      test_result$p < 0.05,
      "Evidence of pre-trends (violates parallel trends assumption)",
      "No evidence of pre-trends (supports parallel trends assumption)"
    )
  )
  
  return(result)
}