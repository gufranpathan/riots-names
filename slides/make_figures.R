# Draw the deck's figures into figures/ next to this script, as PDF files saved with
# cairo_pdf (fonts embedded). Data: the targets pipeline's panel for the frozen name
# index, rni_riots_iyer_frozen (riot years 1970-1995; name outcomes of the cohort born
# in t+1). Run from the project root (renv) after targets::tar_make():
#   Rscript --no-save --no-restore slides/make_figures.R
#
# Size. Each figure is drawn 7.5 in wide for the full 147 mm text width, so it shows at
# 77% of its drawn size and base_size = 11 gives text of about 8.5 pt on the slide. Drawn
# heights stay at or below 3 in (59 mm shown) to fit under a title and a figure note.

suppressMessages({
  library(targets)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(patchwork)
})

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
out_dir <- file.path(if (length(script) == 1) dirname(script) else "slides", "figures")

# The deck's palette (beamer_theme.tex), with light steps
figure_colours <- c(ink = "#1f2633", muted = "#5d6675", hairline = "#e6e9ee",
                    accent = "#a51c30", accent_light = "#d98894",
                    grey = "#8a93a3", grey_light = "#c9cfd8")

figure_theme <- function(base_size = 11) {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(panel.grid = element_blank(),
          panel.grid.major.y = element_line(colour = figure_colours[["hairline"]], linewidth = 0.4),
          axis.text = element_text(colour = figure_colours[["ink"]]),
          axis.title = element_text(colour = figure_colours[["muted"]], size = rel(0.85)),
          strip.text = element_text(colour = figure_colours[["ink"]], face = "bold", hjust = 0),
          plot.title = element_text(colour = figure_colours[["ink"]], face = "bold", size = rel(0.95)),
          plot.background = element_rect(fill = "white", colour = NA))
}

save_figure <- function(plot, name, height, width = 7.5) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(out_dir, paste0(name, ".pdf"))
  ggsave(path, plot, width = width, height = height, bg = "white", device = cairo_pdf)
  path
}

group_colours <- c(`TRUE` = figure_colours[["accent"]], `FALSE` = figure_colours[["grey"]])
index_labels <- c(rni_Muslim_lead = "Muslim name index", rni_Hindu_lead = "Hindu name index")

panel <- tar_read(rni_riots_iyer_frozen)
# Own-district riots are recorded only for districts on the 1981 list
on_list <- panel %>% filter(matched)

# ---- Name index by birth cohort, districts with and without a riot ----
trends <- on_list %>%
  group_by(district_id) %>%
  mutate(ever_riot = max(riot) == 1) %>%
  ungroup() %>%
  mutate(birth_year = year + 1) %>%
  pivot_longer(c(rni_Muslim_lead, rni_Hindu_lead), names_to = "outcome", values_to = "index") %>%
  group_by(outcome, ever_riot, birth_year) %>%
  summarise(index = mean(index), districts = n_distinct(district_id), .groups = "drop") %>%
  mutate(outcome = factor(index_labels[outcome], levels = index_labels))
district_counts <- on_list %>%
  group_by(district_id) %>%
  summarise(ever_riot = max(riot) == 1) %>%
  count(ever_riot)
line_labels <- trends %>%
  filter(birth_year == max(birth_year)) %>%
  left_join(district_counts, by = "ever_riot") %>%
  mutate(label = paste0(ifelse(ever_riot, "Riot", "No riot"), " (", n, ")"))

index_trends <- ggplot(trends, aes(x = birth_year, y = index, colour = ever_riot)) +
  geom_line(linewidth = 0.8) +
  geom_text(data = line_labels, aes(label = label), hjust = -0.08, size = 3.1, show.legend = FALSE) +
  facet_wrap(~outcome, scales = "free_y") +
  scale_colour_manual(values = group_colours, guide = "none") +
  scale_x_continuous(breaks = seq(1975, 1995, 5), expand = expansion(mult = c(0.02, 0.32))) +
  labs(x = "Birth year", y = NULL) +
  figure_theme()

# ---- Distribution of the name index by riot and by Friday festival ----
distributions <- bind_rows(
  on_list %>% transmute(rni_Muslim_lead, rni_Hindu_lead, flag = riot == 1, split = "By riot"),
  panel %>% transmute(rni_Muslim_lead, rni_Hindu_lead, flag = fes_iyer == 1, split = "By Friday festival")
) %>%
  pivot_longer(c(rni_Muslim_lead, rni_Hindu_lead), names_to = "outcome", values_to = "index") %>%
  mutate(outcome = factor(index_labels[outcome], levels = index_labels),
         split = factor(split, levels = c("By riot", "By Friday festival")))

index_distribution <- ggplot(distributions, aes(x = index, colour = flag)) +
  geom_density(linewidth = 0.7) +
  facet_grid(split ~ outcome, scales = "free_y") +
  scale_colour_manual(values = group_colours, guide = "none") +
  scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.25), labels = c("0", "0.25", "0.5", "0.75", "1")) +
  labs(x = "Name index of the cohort born in t+1", y = "Density") +
  figure_theme() +
  theme(strip.text.y = element_text(angle = 0, hjust = 0),
        panel.spacing.y = unit(12, "pt"),
        panel.spacing.x = unit(18, "pt"))

# ---- Friday festivals and riots by year ----
by_year <- panel %>%
  group_by(year) %>%
  summarise(festival = sum(fes_iyer), riot = sum(riot[matched]))
festivals <- ggplot(by_year, aes(x = year, y = festival)) +
  geom_col(fill = figure_colours[["grey"]], width = 0.75) +
  scale_x_continuous(breaks = seq(1970, 1995, 5)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(title = paste0("Districts with a Friday festival (of ", n_distinct(panel$district_id), ")"),
       x = "Riot year", y = NULL) +
  figure_theme()
riots <- ggplot(by_year, aes(x = year, y = riot)) +
  geom_col(fill = figure_colours[["accent"]], width = 0.75) +
  scale_x_continuous(breaks = seq(1970, 1995, 5)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(title = paste0("Districts with a riot (of ", n_distinct(on_list$district_id), " on the 1981 list)"),
       x = "Riot year", y = NULL) +
  figure_theme()

cat(save_figure(index_trends, "index_trends", height = 2.9),
    save_figure(index_distribution, "index_distribution", height = 3.0),
    save_figure(festivals + riots, "festivals_riots", height = 2.8),
    sep = "\n")
