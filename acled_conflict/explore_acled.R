library(acled.api)
library(tidyverse)
library(gghdx)
gghdx()

df <- acled.api(
  email.address = Sys.getenv("EMAIL_ADDRESS_WORK"),
  access.key = Sys.getenv("ACLED_API_KEY")
)

# focus just on violent events
df_conflict <- filter(
  df, 
  event_type %in% c("Battles", "Violence against civilians", "Explosions/Remote violence")
) %>%
  mutate(
    event_date = as.Date(event_date)
  )

#################################
#### Time trends of conflict ####
#################################

df_country_average <- df_conflict %>%
  mutate(
    month = month(event_date),
    date = my(paste(month, year))
  ) %>%
  group_by(
    country,
    date
  ) %>%
  summarize(
    events = n(),
    .groups = "drop"
  ) %>%
  filter(
    date != "2023-08-01"
  ) %>%
  complete(
    country,
    date,
    fill = list(
      events = 0
    )
  )

df_overall_average <- df_country_average %>%
  group_by(date) %>%
  summarize(
    date = unique(date),
    events = mean(events),
    .groups = "drop"
  )

p_line <- df_country_average %>%
  ggplot(
    aes(
      x = date,
      y = events
    )
  ) +
  geom_line(
    aes(
      group = country
    ),
    color = hdx_hex("gray-light")
  ) +
  geom_line(
    data = df_overall_average
  ) +
  labs(
    x = "",
    y = "# of events",
    title = "# of conflict events recorded monthly, by country"
  )

p_line +
  geom_text_hdx(
    x = as.Date("2004-01-01"),
    y = 200,
    label = "Average",
    color = hdx_hex("sapphire-hdx"),
    check_overlap = TRUE,
    fontface = "bold"
  )

p_line +
  scale_y_log10_hdx() +
  geom_text_hdx(
    x = as.Date("2014-01-01"),
    y = 1.75,
    label = "January 2018",
    color = hdx_hex("sapphire-hdx"),
    check_overlap = TRUE,
    fontface = "bold"
  ) +
  geom_segment(
    x = as.Date("2016-01-01"),
    xend = as.Date("2017-11-01"),
    y = 1.75,
    yend = 1.75,
    arrow = arrow(length = unit(0.1, "cm")),
    color = hdx_hex("sapphire-hdx")
  ) +
  geom_text_hdx(
    x = as.Date("2006-01-01"),
    y = 0.5,
    label = "January 2010",
    color = hdx_hex("sapphire-hdx"),
    check_overlap = TRUE,
    fontface = "bold"
  ) +
  geom_segment(
    x = as.Date("2008-01-01"),
    xend = as.Date("2009-11-01"),
    y = 0.5,
    yend = 0.5,
    arrow = arrow(length = unit(0.1, "cm")),
    color = hdx_hex("sapphire-hdx")
  )

############################################
#### Earliest date of events by country ####
############################################

p_start_dates <- df_conflict %>%
  group_by(
    country
  ) %>%
  summarize(
    event_date = min(event_date)
  ) %>%
  ggplot() +
  geom_histogram(
    aes(
      x = event_date
    ),
    color = "black",
    stat = "count"
  ) +
  scale_x_date(
    date_breaks = "2 years",
    date_label = "%Y"
  ) +
  labs(
    x = "Date of first event for country",
    y = "# of countries",
    title = "Date of first recorded conflict event by country"
  )

p_start_dates

##########################################################
#### Look at size of events as measured by fatalities ####
##########################################################

df_fatal <- df_conflict %>%
  group_by(
    event_date
  ) %>%
  summarize(
    fatalities = mean(fatalities, na.rm = TRUE)
  )


df_fatal %>%
  ggplot(
    aes(
      x = event_date,
      y = fatalities
    )
  ) +
  geom_smooth() +
  scale_y_continuous_hdx() +
  labs(
    x = "",
    y = "Mean fatalities per event",
    title = "Fatalities per reported event across time"
  )

########################################
#### Countries by year of inclusion ####
########################################

df_conflict %>%
  group_by(
    country
  ) %>%
  summarize(
    year = min(year)
  ) %>%
  group_by(
    year
  ) %>%
  arrange(
    desc(country),
    .by_group = TRUE
  ) %>%
  mutate(
    y = row_number()
  ) %>%
  ggplot(
    aes(
      x = year,
      y = y,
      label = country
    )
  ) +
  geom_rect(
    ymin = -Inf,
    ymax = Inf,
    xmin = 2017,
    xmax = 2019,
    fill = hdx_hex("tomato-ultra-light")
  ) +
  geom_text_hdx(
    size = 3
  ) +
  scale_x_continuous(
    breaks = c(
      seq(2000, 2015, by = 5),
      2018,
      2020
    )
  ) +
  theme(
    axis.text.y = element_blank(),
    panel.grid = element_blank()
  ) +
  labs(
    x = "",
    y = "",
    title = "Year of first reported event"
  )

############################
#### EXPLORE THRESHOLDS ####
############################

df_filtered <- filter(df_conflict, year >= 2018)

df_events <- df_filtered %>%
  group_by(
    country,
    event_date
  ) %>%
  summarize(
    n = n(),
    .groups = "drop_last"
  ) %>%
  complete(
    event_date = seq.Date(from = as.Date("2018-01-01"), to = max(df_filtered$event_date), by = "day"),
    fill = list(
      n = 0
    )
  ) %>%
  mutate(
    rs_7 = zoo::rollsumr(
      x = n,
      k = 7,
      fill = NA
    ),
    rs_30 = zoo::rollsumr(
      x = n,
      k = 30,
      fill = NA
    ),
    rs_90 = zoo::rollsumr(
      x = n,
      k = 90,
      fill = NA
    ),
    rs_365 = zoo::rollsumr(
      x = n,
      k = 365,
      fill = NA
    )
  )

##############################
#### FATALITIES VS EVENTS ####
##############################

df_country_compare <- df_conflict %>%
  group_by(
    event_date,
    country
  ) %>%
  summarize(
    fatalities = mean(fatalities, na.rm = TRUE),
    events = n(),
    .groups = "drop"
  )

p_conflict_events <- df_country_compare %>%
  ggplot(
    aes(
      x = fatalities,
      y = events
    )
  ) +
  geom_point(
    alpha = 0.05
  ) +
  labs(
    x = "Fatalities",
    y = "Events",
    title = "Daily events and fatalities at the country level"
  ) +
  scale_y_continuous_hdx()

# now look at countries that are responsible for some of the event outliers
df_country_compare %>%
  filter(
    events >= 50,
    fatalities <= 1
  ) %>%
  group_by(
    country
  ) %>%
  summarize(
    n = n(),
    n_zero = sum(fatalities == 0)
  ) %>%
  ggplot(
    aes(
      y = fct_reorder(country, n)
    )
  ) +
  geom_bar(
    aes(
      x = n
    ),
    stat = "identity"
  ) +
  geom_bar(
    aes(
      x = n_zero
    ),
    stat = "identity",
    fill = hdx_hex("sapphire-hdx")
  ) +
  labs(
    y = "",
    x = "# of days",
    title = "Days with 50+ events reported with 1 or fewer fatalities",
    subtitle = "Days with 0 fatalities in blue"
  )

# now look at those fatalities outliers
df_country_compare %>%
  filter(
    events <= 5,
    fatalities >= 250
  ) %>%
  group_by(
    country
  ) %>%
  summarize(
    n = n(),
    n_one = sum(events == 1)
  ) %>%
  ggplot(
    aes(
      y = fct_reorder(country, n)
    )
  ) +
  geom_bar(
    aes(
      x = n
    ),
    stat = "identity"
  ) +
  geom_bar(
    aes(
      x = n_one
    ),
    stat = "identity",
    fill = hdx_hex("sapphire-hdx")
  ) +
  labs(
    y = "",
    x = "# of days",
    title = "Days with 250+ fatalities reported with 5 or fewer conflict events",
    subtitle = "Days with 250+ fatalities in a single event"
  )

# years of events

df_country_compare %>%
  filter(
    events <= 5,
    fatalities >= 250
  ) %>%
  ggplot(
    aes(
      x = event_date
    )
  ) +
  geom_histogram() +
  scale_y_continuous_hdx() +
  labs(
    x = "",
    y = "# of country-days",
    title = "Country-days with 250+ fatalities and 5 or fewer events"
  ) +
  geom_text_hdx(
    data = data.frame(
      event_date = as.Date(c("2018-02-15", "2021-07-24")),
      y = 3,
      label = c("Nigeria", "Ethiopia")
    ),
    mapping = aes(
      y = y,
      label = label
    ),
    angle = -90,
    hjust = 1,
    size = 5
  )

# quickly check what relationship looks like since 2018

df_country_compare %>%
  filter(
    event_date >= "2018-01-01"
  ) %>%
  ggplot(
    aes(
      x = fatalities,
      y = events
    )
  ) +
  geom_point(
    alpha = 0.05
  ) +
  labs(
    x = "Fatalities",
    y = "Events",
    title = "Daily events and fatalities at the country level"
  ) +
  scale_y_continuous_hdx()

###################################
#### DIFFERENT FLAGGING LEVELS ####
###################################

countries_of_interest <- c(
  "Afghanistan", 
  "Syria",
  "Myanmar",
  "Sudan",
  "South Sudan",
  "Democratic Republic of Congo",
  "Haiti",
  "Armenia",
  "Ukraine"
)


df_flags <- df_country_compare %>%
  filter(
    event_date >= "2018-01-01",
    country %in% countries_of_interest
  ) %>%
  complete(
    country,
    event_date = seq.Date(
      from = as.Date("2018-01-01"),
      to = Sys.Date(),
      by = "day"
    ),
    fill = list(
      fatalities = 0,
      events = 0
    )
  ) %>%
  group_by(
    country
  ) %>%
  mutate(
    month = month(event_date),
    year = year(event_date),
    date = ymd(paste0(year, "-01-01")) + months(month - 1)
  ) %>%
  group_by(
    country,
    date,
    year,
    month
  ) %>%
  summarize(
    events = sum(events),
    fatalities = sum(fatalities),
    .groups = "drop"
  ) %>%
  group_by(
    country
  ) %>%
  mutate(
    threshold_fatalities = quantile(fatalities, 0.9),
    threshold_events = quantile(events, 0.9),
    flag_fatalities = fatalities >= threshold_fatalities,
    flag_events = events >= threshold_events
  )

# fatality flags
df_flags_fatal <- df_flags %>%
  filter(
    flag_fatalities
  ) %>%
  mutate(
    flag_group = cumsum(month - lag(month, default = 0) != 1)
  ) %>%
  group_by(
    country,
    flag_group
  ) %>%
  summarize(
    start_date = min(date),
    end_date = max(date) + months(1) - days(1),
    .groups = "drop"
  )

df_flags_event <- df_flags %>%
  filter(
    flag_events
  ) %>%
  mutate(
    flag_group = cumsum(month - lag(month, default = 0) != 1)
  ) %>%
  group_by(
    country,
    flag_group
  ) %>%
  summarize(
    start_date = min(date),
    end_date = max(date) + months(1) - days(1),
    .groups = "drop"
  )

df_flags_both <- df_flags %>%
  filter(
    flag_events,
    flag_fatalities
  ) %>%
  mutate(
    flag_group = cumsum(month - lag(month, default = 0) != 1)
  ) %>%
  group_by(
    country,
    flag_group
  ) %>%
  summarize(
    start_date = min(date),
    end_date = max(date) + months(1) - days(1),
    .groups = "drop"
  )

# now plot them all together
# first just plot the fatalities and events

df_flags %>%
  mutate(
    fatalities_norm = (fatalities - min(fatalities)) / (max(fatalities) - min(fatalities)),
    events_norm = (events - min(events)) / (max(events) - min(events))
  ) %>%
  pivot_longer(
    ends_with("norm")
  ) %>%
  ggplot(
    aes(
      x = date,
      y = value,
      group = name,
      color = name
    )
  ) +
  geom_line() +
  facet_wrap(
    ~ country,
    scales = "free_y"
  ) +
  scale_color_manual(
    values = c("black", "darkgrey"),
    labels = c("Events", "Fatalities")
  ) +
  labs(
    x = "",
    y = "Normalized value",
    color = "",
    title = "Events and fatalities by country, normalized between 0 and 1"
  )


bind_rows(
  df_flags_event %>% mutate(type = "Events"),
  df_flags_fatal %>% mutate(type = "Fatalities"),
  df_flags_both %>% mutate(type = "Both")
) %>%
  ggplot(
    aes(
      xmin = start_date,
      xmax = end_date,
      group = type,
      fill = type
    )
  ) +
  geom_rect(
    ymin = 0,
    ymax = Inf
  ) +
  scale_fill_manual(
    values = c(hdx_hex("tomato-hdx"), "black", "darkgrey")
  ) +
  facet_wrap(
    ~ country,
    scales = "free_y"
  ) +
  labs(
    x = "",
    fill = "Alert",
    title = "Country alerts generated from monthly anomalies >= 90%"
  )

#################################
#### Threshold determination ####
#################################

df_country_compare %>%
  filter(
    event_date >= "2018-01-01"
  ) %>%
  complete(
    country,
    event_date = seq.Date(
      from = as.Date("2018-01-01"),
      to = Sys.Date(),
      by = "day"
    ),
    fill = list(
      fatalities = 0,
      events = 0
    )
  ) %>%
  group_by(
    country
  ) %>%
  mutate(
    month = month(event_date),
    year = year(event_date),
    date = ymd(paste0(year, "-01-01")) + months(month - 1)
  ) %>%
  group_by(
    country,
    date,
    year,
    month
  ) %>%
  summarize(
    events = sum(events),
    fatalities = sum(fatalities),
    .groups = "drop"
  ) %>%
  group_by(
    country
  ) %>%
  mutate(
    threshold_fatalities = quantile(fatalities, 0.9),
    threshold_events = quantile(events, 0.9),
    flag_fatalities = fatalities >= threshold_fatalities,
    flag_events = events >= threshold_events
  )
