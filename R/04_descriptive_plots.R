get_rni_densities_plot <- function(iv_models, rni_riots){
  # tar_load(iv_models)
  # tar_load(rni_riots)
  path_tracking_vector <- c()
  
   outcome <- 'rni_Muslim_lead'
  
  muslim_model <- iv_models[['muslim_models']][[1]]
  
  
  rni_riots$fitted_riot <- fitted(muslim_model$iv_first_stage$riot)
  
  table(rni_riots$fitted_riot,rni_riots$fridayfestival)
  
  
  min_fit_riot <- min(rni_riots$fitted_riot)
  max_fit_riot <- max(rni_riots$fitted_riot)
  
  rni_riots <- rni_riots %>% 
    mutate(fitted_riot_category=if_else(fitted_riot==min_fit_riot,'Baseline','Festival-induced riots'))
  
  output_path <- "data/02_output/04_plots/"
  
  # Create output directory
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  # Define consistent theme
  plot_theme <- theme_bw(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      legend.position = c(0.02, 0.9),
      legend.justification = "left",
      legend.background = element_blank(),
      legend.key = element_blank(),
      plot.title = element_text(face = "bold", size = 11),
      axis.title = element_text(face = "bold", size = 10),
      axis.text = element_text(size = 9),
      plot.margin = margin(10, 10, 10, 10)
    )
  
  # Color palette
  colors <- c("0" = "#0C7BDC", "1" = "#E66100")
  labels <- c("0" = "No Riot", "1" = "Riot")
  
  # Calculate means for annotation
  muslim_mean_no_riot <- mean(rni_riots$rni_Muslim_lead[rni_riots$riot == 0], na.rm = TRUE)
  muslim_mean_riot <- mean(rni_riots$rni_Muslim_lead[rni_riots$riot == 1], na.rm = TRUE)
  hindu_mean_no_riot <- mean(rni_riots$rni_Hindu_lead[rni_riots$riot == 0], na.rm = TRUE)
  hindu_mean_riot <- mean(rni_riots$rni_Hindu_lead[rni_riots$riot == 1], na.rm = TRUE)
  
  # Panel A: Muslim Name Distinctiveness
  plot_muslim <- ggplot(rni_riots, aes(x = rni_Muslim_lead, 
                                       color = as.factor(riot))) +
    geom_density(alpha = 0.15, linewidth = 1) +
    scale_color_manual(
      values = colors,
      labels = labels,
      name = NULL
    ) +
    scale_x_continuous(
      breaks = seq(0, 1, 0.25),
      limits = c(0, 1)
    ) +
    labs(
      title = "A: Muslim Name Index by Riot Exposure",
      x = "Muslim Name Index ( y + 1 )",
      y = "Density"
    ) +
    theme_bw(base_size = 11) +
      plot_theme
  
  # Panel B: Hindu Name Distinctiveness
  plot_hindu <- ggplot(rni_riots, aes(x = rni_Hindu_lead, 
                                      color = as.factor(riot))) +
    geom_density(alpha = 0.15, linewidth = 1) +
    scale_color_manual(
      values = colors,
      labels = labels,
      name = NULL
    ) +
    scale_x_continuous(
      breaks = seq(0, 1, 0.25),
      limits = c(0, 1)
    ) +
    labs(
      title = "B: Hindu Name Index by Riot Exposure",
      x = "Hindu Name Index ( y + 1 )",
      y = "Density"
    ) +
    plot_theme
  
  colors <- c("0" = "#0C7BDC", "1" = "#E66100")
  labels <- c("0" = "No Friday Festival", "1" = "Friday Festival")
  
  # Muslim plot
  plot_muslim_ff <- ggplot(rni_riots, aes(x = rni_Muslim_lead, 
                                          color = as.factor(fridayfestival))) +
    geom_density(alpha = 0.15, linewidth = 1) +
    scale_color_manual(values = colors, labels = labels, name = NULL) +
    scale_x_continuous(breaks = seq(0, 1, 0.25), limits = c(0, 1)) +
    labs(
      title = "C: Muslim Name Index by Friday Festival",
      x = "Muslim Name Index ( y + 1 )",
      y = "Density"
    ) +
    plot_theme
  
  # Hindu plot
  plot_hindu_ff <- ggplot(rni_riots, aes(x = rni_Hindu_lead, 
                                         color = as.factor(fridayfestival))) +
    geom_density(alpha = 0.15, linewidth = 1) +
    scale_color_manual(values = colors, labels = labels, name = NULL) +
    scale_x_continuous(breaks = seq(0, 1, 0.25), limits = c(0, 1)) +
    labs(
      title = "D: Hindu Name Index by Friday Festival",
      x = "Hindu Name Index ( y + 1 )",
      y = "Density"
    ) +
    plot_theme
  
  
  index_density_plot <- (plot_muslim + plot_hindu ) /
    (plot_muslim_ff + plot_hindu_ff )+
    plot_annotation(
      title = "Distribution of Name Index by Riot Exposure & Friday Festival",
      theme = theme(
        plot.title = element_text(face = "bold", size = 12),
        plot.caption = element_text(hjust = 0, size = 9, face = "italic")
      )
    )
  
  save_track_plot(index_density_plot,output_path=output_path,height = 2400,width=2400,units = 'px')
  
  return(path_tracking_vector)
  
}


get_time_trends_by_riot <- function(rni_riots){
  # tar_load(rni_riots)
  
  path_tracking_vector <- c()
  output_path <- "data/02_output/04_plots/"
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  
  plot_theme <- theme_bw(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
      legend.position = c(0.02, 0.9),
      legend.justification = "left",
      legend.background = element_blank(),
      legend.key = element_blank(),
      plot.title = element_text(face = "bold", size = 11),
      axis.title = element_text(face = "bold", size = 10),
      axis.text = element_text(size = 9),
      plot.margin = margin(10, 10, 10, 10)
    )
  
  
  colors <- c("0" = "#0C7BDC", "1" = "#E66100")
  labels <- c("0" = "Never Riot", "1" = "Atleast One Riot")
  
  muslim_trends <- rni_riots %>% 
    group_by(year, ever_riot) %>% 
    summarize(rni_Muslim=mean(rni_Muslim,na.rm=T)) %>% 
    ggplot(aes(x=year,y=rni_Muslim,col=as.factor(ever_riot)))+
    geom_line(linewidth = 1)+
    scale_color_manual(
      values = colors,
      labels = labels,
      name = NULL
    ) +
    labs(
      title = "A: Muslim Name Index over time",
      x = "Year",
      y = "Muslim Name Index"
    ) +
    theme_bw(base_size = 11) +
    scale_y_continuous(
      # breaks = seq(0, 1, 0.2),
      limits = c(0.7, 0.85)
    ) +
    plot_theme  
  
  hindu_trends <- rni_riots %>% 
    group_by(year, ever_riot) %>% 
    summarize(rni_Hindu=mean(rni_Hindu,na.rm=T)) %>% 
    ggplot(aes(x=year,y=rni_Hindu,col=as.factor(ever_riot)))+
    geom_line(linewidth = 1)+
    scale_color_manual(
      values = colors,
      labels = labels,
      name = NULL
    ) +
    labs(
      title = "B: Hindu Name Index over time",
      x = "Year",
      y = "Hindu Name Index"
    ) +
    theme_bw(base_size = 11) +
    scale_y_continuous(
      # breaks = seq(0, 1, 0.2),
      limits = c(0.7, 0.85)
    ) +
    plot_theme  
  
index_trend_plot <- (muslim_trends + hindu_trends)+
    plot_annotation(
      title = "Time Trends of Name Index",
      theme = theme(
        plot.title = element_text(face = "bold", size = 12),
        plot.caption = element_text(hjust = 0, size = 9, face = "italic")
      )
    )
  
  save_track_plot(index_trend_plot,output_path=output_path,height = 1200,width=2400,units = 'px')
  
  return(path_tracking_vector)
}


get_riot_friday_festival_trend <- function(rni_riots){
  # tar_load(rni_riots)
  
  output_path <- "data/02_output/04_plots/"
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  path_tracking_vector <- c()
  
  # festival_riot_year <- rni_riots %>% 
  #   mutate(festival_riot = 
  #            case_when(
  #              (riot==1) & (fridayfestival==1) ~"Riot & Friday Festival",
  #              (riot==1) & (fridayfestival==0) ~"Riot Only",
  #              (riot==0) & (fridayfestival==1) ~"Friday Festival Only",
  #              .default = NA
  #            )) %>% 
  #   filter(!is.na(festival_riot)) %>% 
  #   group_by(year,festival_riot) %>% 
  #   summarize(events=n())
  # 
  # ggplot(aes(x=year,y=events),data=festival_riot_year)+
  #   geom_col(alpha=0.5)+
  #   facet_grid(festival_riot~.,scales="free_y")+
  #   theme_minimal()
  
  fridayfestivalplot <- rni_riots %>% 
    group_by(year) %>% 
    summarise(fridayfestival=sum(fridayfestival,na.rm=T)) %>% 
    ungroup() %>% 
    # mutate(fridayfestival=if_else(fridayfestival==0,NA,fridayfestival)) %>% 
    ggplot(aes(x=year,y=fridayfestival))+
    geom_col(alpha=0.5)+
    scale_x_continuous(breaks=seq(1950,1995,5))+
    theme_minimal()+
    labs(x='Year',
         y='No. of districts',
         title='Friday Festivals')
  
  
  riotplot <- rni_riots %>% 
    group_by(year) %>% 
    summarise(riot=sum(riot,na.rm=T)) %>% 
    ungroup() %>% 
    # mutate(riot=if_else(riot==0,NA,riot)) %>% 
    ggplot(aes(x=year,y=riot))+
    geom_col(alpha=0.5)+
    scale_x_continuous(breaks=seq(1950,1995,5))+
    theme_minimal()+
    labs(x='Year',
         y='No. of districts',
         title='Riots')
  
  riot_friday_festival_trend <- (fridayfestivalplot / riotplot)+
    plot_annotation(
      title = "Temporal Trends of Friday Festivals and Riots",
      theme = theme(
        plot.title = element_text(face = "bold", size = 12),
        plot.caption = element_text(hjust = 0, size = 9, face = "italic")
      )
    )
  
  save_track_plot(riot_friday_festival_trend,output_path=output_path,height = 1500,width=3000,units = 'px')
  
  return(path_tracking_vector)

}