# libraries

# for installing rhdx
# install.packages("remotes")
# remotes::install_gitlab("dickoa/rhdx")

library(tidyverse)
library(tidyquant)
library(gghdx)
library(rhdx)
library(zoo)
gghdx()

# rhdx config
set_rhdx_config(hdx_site = "prod")
get_rhdx_config()

# reading in the global dataset
wfp_glb <- read_csv("https://data.humdata.org/dataset/31579af5-3895-4002-9ee3-c50857480785/resource/0f2ef8c4-353f-4af1-af97-9e48562ad5b1/download/wfp_countries_global.csv")[-1,]

# searching for wfp food price datasets on HDX and reading in resources
# restrict to only WFP datasets
wfp_fp_resources <- wfp_glb %>% 
  mutate(data_id = str_replace(url, "https://data.humdata.org/dataset/", "")) %>%
  pull(data_id) %>%
  map(~ pull_dataset(.) %>%
        get_resource(1) %>%
        read_resource()) %>%
  set_names(wfp_glb$countryiso3) %>%
  bind_rows(.id = "countryiso3")

#wfp_fp_datasets <- search_datasets(" - Food Prices", rows = 300) %>%
#  purrr::set_names(map(., ~.x$data$title)) %>%
#  subset(names(.) != "Global - Food Prices") %>%
#  map(~.x %>% 
#        get_resource(1) %>%
#        read_resource()) 

# removing possible duplicates
#wfp_fp_resources <- wfp_fp_datasets %>%
#  names() %>%
#  duplicated() %>%
#  `!`() %>%
#  wfp_fp_datasets[.]

# exploring possible thresholds overall and for each country
# Q1: Do different countries tend to have lower prices than others?
# Q2: Pricetype: Wholesale vs retail, how large is the difference?
# Q3: Which category/commodity tends to be the most expensive?
# Q4: Which category/commodity would be a good indicator of average prices?
# Q5: Do different admin 1s and 2s have drastic changes in price?
# Q6: Should we use local currency or USD? If we aim to compare across countries/regions then use USD.
# Q7: Are we interested if price goes up in one country or all?                              

# starting with which category would be a good indicator of average prices
# Ethiopia: 
eth_wfp <- wfp_fp_resources %>%
  filter(countryiso3 == "ETH")

# using Local
eth_wfp %>%
  filter(category == "cereals and tubers") %>%
  ggplot(aes(x=date, y=price)) +
  geom_line() + 
  geom_smooth(method=lm) +
  facet_wrap(vars(admin1))

# using USD
eth_wfp %>%
  filter(category == "cereals and tubers") %>%
  ggplot(aes(x=date, y=usdprice)) +
  geom_line() + 
  geom_smooth(method=lm) +
  facet_wrap(vars(admin1))

# prices tend to increase over time but the trend tends to be increasing
# almost at the same rate for most admin 1s
# looking at using % increase over time

uniq_cats <- eth_wfp %>%
  select(category, commodity, unit, pricetype) %>%
  distinct()

price_type <- eth_wfp %>%
  group_by(category, pricetype, unit) %>%
  summarise(avg_price = mean(usdprice, na.rm = T)) %>%
  mutate(avg_price_c = case_when(unit == "100 KG" ~ avg_price/100, .default = avg_price),
         pricetype_unit = paste(pricetype, "-", unit))

ggplot(price_type, aes(x = category, y = avg_price_c, fill = pricetype_unit)) +
  geom_bar(stat = "identity", position = position_dodge2(width = 0.7, preserve = "single")) +
  labs(title = "Average Prices for Food Categories - Ethiopia",
       x = "Category",
       y = "Price (USD)") 

# Which commodity would be a good indicator of prices?
# Possible: % of commodities with above a certain % increase in prices.
# What level of % increase would be seen as abnormal and warrant an alert?

annual_inc_df <- eth_wfp %>%
  mutate(year = format(as.Date(date), "%Y"),
         pricetype_unit = paste(pricetype, "-", unit)) %>%
  arrange(commodity, date) %>%
  group_by(year, commodity, pricetype_unit) %>%
  summarize(annual_inc = (last(usdprice) - first(usdprice)) / first(usdprice) * 100) %>%
  group_by(year) %>%
  summarise(perc = mean(annual_inc > 1) * 100)

# looking at a 1-in-5 year RP
ggplot(annual_inc_df, aes(x = year, y = perc, group = 1)) +
  geom_line()

# Monday 29th:
# 1. Look at the % number of commodities with an % increase above a RP
# 2. Look at the % number of admin1s/admin2s with % number of commodities with an % increase above a RP
# 3. Which commodity would be a good indicator of prices?
# 4. The staple food prices? What is available across multiple countries.
# 5. What IPC/FEWSNET takes into account for analysis? 
# 6. Look at only retail prices maybe?
# 7. Price increases differing from price increase across other countries.
# 8. Compare 3-month vs 1-month changes
