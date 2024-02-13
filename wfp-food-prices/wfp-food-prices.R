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
options(scipen = 9999)

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
wfp_fp_resources %>%
  filter(category == "cereals and tubers") %>%
  ggplot(aes(x=date, y=price)) +
  geom_line() + 
  geom_smooth(method=lm) +
  facet_wrap(vars(countryiso3))

# using USD
wfp_fp_resources %>%
  filter(category == "cereals and tubers") %>%
  ggplot(aes(x=date, y=usdprice)) +
  geom_line() + 
  geom_smooth(method=lm) +
  facet_wrap(vars(countryiso3))

# prices tend to increase over time but the trend tends to be increasing
# looking at using % increase over time

uniq_cats <- wfp_fp_resources %>%
  select(category, commodity, unit, pricetype) %>%
  distinct()

price_type <- wfp_fp_resources %>%
  group_by(category, pricetype, unit) %>%
  summarise(avg_price = mean(usdprice, na.rm = T)) %>%
  mutate(avg_price_norm = case_when(unit == "100 KG" ~ avg_price/100, .default = avg_price),
         pricetype_unit = paste(pricetype, "-", unit))

ggplot(price_type, aes(x = category, y = avg_price_norm, fill = pricetype_unit)) +
  geom_bar(stat = "identity", position = position_dodge2(width = 0.7, preserve = "single")) +
  labs(title = "Average Prices for Food Categories - Global",
       x = "Category",
       y = "Price (USD)") 

# Which commodity would be a good indicator of prices?
# Possible: % of commodities with above a certain % increase in prices.
# What level of % increase would be seen as abnormal and warrant an alert?

annual_inc_df <- wfp_fp_resources %>%
  mutate(year = format(as.Date(date), "%Y"),
         pricetype_unit = paste(pricetype, "-", unit)) %>%
  arrange(commodity, date) %>%
  group_by(year, commodity, pricetype_unit) %>%
  summarize(annual_inc = (last(usdprice) - first(usdprice)) / first(usdprice) * 100) %>%
  group_by(year) %>%
  summarise(perc = mean(annual_inc > 5, na.rm = TRUE) * 100)

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
# 8. Compare 3-month vs 1-month changes vs 6-month
# 9. Should we focus on varieties of commodities or only on a base one?

# looking at which commodity would be a good indicator of prices
unique(wfp_fp_resources$pricetype)
# are all price types available in all markets?
# how many markets are there?
wfp_fp_resources %>%
  unite("unique_market", countryiso3, admin1, admin2, market, sep = "_") %>%
  summarise(n_distinct(unique_market))

# there look to be 3689 markets

### NEW STRATEGY
# looking at 3-month periods
# Medium Concern: Highest price in the past 1 year
# High Concern: Highest price in the last 3 years
# Minimum threshold

## We start by normalising the prices to one measure of mass.
## From the data, it does not look like all commodities have a common unit. 

## Check by category if each commodity has values in KG.
## first check the proportion of each unit by category
## this is to try and get the most common unit for each category
cat_prop <- wfp_fp_resources %>%
  filter(pricetype == "Retail" & category != "non-food") %>%
  group_by(category, unit) %>%
  summarise(count = n()) %>%
  ungroup() %>%
  mutate(proportion = count / sum(count)) %>%
  arrange(category, desc(proportion)) %>%
  group_by(category) %>%
  top_n(3)

## For "cereals and tubers", "meat, fish and eggs", "miscellaneous food",
## "pulses and nuts" and "vegetables and fruits" seem to be mostly available at KG 
## as this is the most common unit.

## "milk and dairy" and "oil and fats" seem to be available as either in L or KG.

## Next step is to confirm that all commodities are available at either L or KG 
## in all markets.

## First, check if retail prices are available in all markets for all commodities.
### using the number of unique markets as the baseline, let's see how many markets 
### have retail prices for all commodities and in which units.

## checking if there are markets with the same name in admin 2: 
## No. All markets in an admin 2 have unique names
wfp_fp_resources %>%
  select(countryiso3, admin1, admin2, market, latitude, longitude) %>%
  distinct() %>%
  group_by(countryiso3, admin1, admin2, market) %>%
  summarise(n_distinct(market))

## are there retail prices for commodities in all markets?
wfp_fp_resources %>%
  group_by(countryiso3, admin1, admin2, market, category, commodity) %>%
  summarise(unique_comm = n_distinct(pricetype)) %>%
  filter(unique_comm > 1)
# in each market, you have at most 2 price types for all commodities. 

wfp_retail <- wfp_fp_resources %>%
  filter(pricetype == "Retail" & category != "non-food")
## are there retail prices in KG or L for all commodities in all markets?
retail_food <- wfp_retail %>%
  # group_by(countryiso3, admin1, admin2, market, category, commodity) %>%
  #summarise(unique_comm = n_distinct(unit, pricetype)) %>%
  filter((unit == "KG" | unit == "L") & category != "non-food")

wfp_retail %>%
  unite("unique_market", countryiso3, admin1, admin2, market, sep = "_") %>%
  summarise(n_distinct(unique_market))

# not all markets have retail prices
wfp_fp_resources %>%
  filter(pricetype != "Retail") %>%
  distinct(countryiso3, market)
# not all markets have retail prices 
# not all markets have retail prices with units in KG or L.

# normalising the prices
unique(wfp_retail$unit)



## I could only find 13 countries from FEWS NET staple food dataset
# Angola, Chad, Congo, The Democratic Republic of the
# Djibouti, Ethiopia, Haiti, Kenya, Malawi, Mauritania, Nigeria
# Somalia, South Sudan, Zimbabwe


View(uniq_cats %>%
       arrange(category, commodity, unit, pricetype))

wfp_fp_resources %>%
  # filter to remove non-food category
  filter(category != "non-food") %>%
  # standardise by commodity
  group_by(countryiso3, commodity) %>%
  arrange(date) %>%
  mutate(
    rolling_avg = zoo::rollapply(usdprice, width = 3, FUN = mean, align = "right", fill = NA)
  )
