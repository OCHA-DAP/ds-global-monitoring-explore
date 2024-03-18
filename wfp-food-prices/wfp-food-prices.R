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
View(uniq_cats %>%
       arrange(category, commodity, unit, pricetype))

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

wfp_norm <- wfp_retail %>%
  filter(date >= (today() - years(5))) %>%
  mutate(unit_std = case_when(
    grepl("\\sG", unit) ~ paste(as.numeric(str_extract(unit, "\\d+"))/1000, "KG"),
    grepl("\\sML", unit) ~ paste(as.numeric(str_extract(unit, "\\d+"))/1000, "L"),
    TRUE ~ unit),
    usdprice_norm = case_when(
      grepl("\\sKG|\\sL", unit_std) ~  (usdprice / as.numeric(str_extract(unit_std, "^[^ ]+"))),
      grepl("\\spcs", unit_std) ~  (usdprice / as.numeric(str_extract(unit_std, "\\d+"))),
      grepl("\\sPounds", unit_std) ~  (usdprice / as.numeric(str_extract(unit_std, "\\d+"))),
      grepl("Gallon", unit_std) ~  (usdprice / 3.78541),
      TRUE ~ usdprice),
    unit_norm = case_when(
      grepl("\\sKG|\\sL", unit_std) ~  sub("^[^ ]+ ", "", unit_std),
      grepl("\\spcs", unit_std) ~  "1 piece",
      grepl("\\sPounds", unit_std) ~  "Pound",
      grepl("Gallon", unit_std) ~  "L",
      TRUE ~ unit_std),
  )

cat_prop_norm <- wfp_norm %>%
  filter(pricetype == "Retail" & category != "non-food") %>%
  group_by(category, unit_norm) %>%
  summarise(count = n()) %>%
  ungroup() %>%
  mutate(proportion = count / sum(count)) %>%
  arrange(category, desc(proportion)) %>%
  group_by(category) %>%
  top_n(3)

unique(wfp_norm$unit_norm)

## I could only find 13 countries from FEWS NET staple food dataset
# Angola, Chad, Congo, The Democratic Republic of the
# Djibouti, Ethiopia, Haiti, Kenya, Malawi, Mauritania, Nigeria
# Somalia, South Sudan, Zimbabwe

## looking at creating a food basket of commodities from each category
## they would be the most available in most markets within a country

food_baskets <- wfp_norm %>%
  group_by(countryiso3, category, commodity) %>%
  summarise(foodcount = n()) %>%
  arrange(countryiso3, category, desc(foodcount)) %>%
  group_by(countryiso3, category) %>%
  slice_head(n = 3) %>%
  ungroup()

## NOTE: some commodities are available as a national average
## filtering for only items per country in the food basket
## Another issue is that not all commodities are available each time.
## filtering for only the last 5 years
wfp_summ <- wfp_norm %>%
  inner_join(food_baskets, by = c("countryiso3", "commodity"), 
             suffix = c("", "_fb")) %>%
  group_by(countryiso3, date) %>%
  summarise(ave_price = mean(usdprice_norm, na.rm = TRUE)) %>%
  group_by(countryiso3) %>%
  arrange(countryiso3, date) %>%
  complete(date = seq.Date(min(date), today(), by = "month")) %>%
  mutate(
    rol_avg = zoo::rollapply(ave_price, width = 3, 
                                 FUN = mean, align = "right", fill = NA),
    percent_increase = (diff(rol_avg)/lag(rol_avg)) * 100
  )

ggplot(wfp_summ) + 
  geom_line(aes(x=date, y=percent_increase)) + 
  facet_wrap(vars(countryiso3))


# get highest value in the last year
med_alert <- wfp_summ %>%
  filter(date >= (today() - years(1))) %>%
  group_by(countryiso3) %>%
  filter(rol_avg == max(rol_avg, na.rm = T))

# get highest value in the last 3 years
high_alert <- wfp_summ %>%
  filter(date >= (today() - years(3))) %>%
  group_by(countryiso3) %>%
  filter(rol_avg == max(rol_avg, na.rm = T))

#### Option 1

wfp_option1 <- wfp_norm %>%
  filter(unit_norm %in% c("KG", "L")) %>%
  group_by(countryiso3, date) %>%
  summarise(ave_price = mean(usdprice_norm, na.rm = TRUE)) %>%
  group_by(countryiso3) %>%
  arrange(countryiso3, date) %>%
  complete(date = seq.Date(min(date), today(), by = "month")) %>%
  mutate(
    rol_avg = zoo::rollapply(ave_price, width = 3, 
                             FUN = mean, align = "right", fill = NA),
    percent_increase = (diff(rol_avg)/lag(rol_avg)) * 100
  )

# get highest value in the last year
med_alert <- wfp_option1 %>%
  filter(date >= (today() - years(1))) %>%
  group_by(countryiso3) %>%
  #filter(rol_avg == max(rol_avg, na.rm = T))
  summarise(rol_max = max(rol_avg, na.rm = T))

# plotting
ggplot(data = med_alert) +
  geom_bar(aes(x = countryiso3, y = rol_max), stat = "identity") + 
  theme(axis.text.x = element_text(angle = 80, hjust = 1, margin = margin(t = -10, r = 10, b = 10, l = 10))) +
  labs(title = "Average Prices for Medium Alerts", y = "Average Price")

# get highest value in the last 3 years
high_alert <- wfp_option1 %>%
  filter(date >= (today() - years(3))) %>%
  group_by(countryiso3) %>%
  #filter(rol_avg == max(rol_avg, na.rm = T))
  summarise(rol_max = max(rol_avg, na.rm = T))

#plotting
ggplot(data = high_alert) +
  geom_bar(aes(x = countryiso3, y = rol_max), stat = "identity") + 
  theme(axis.text.x = element_text(angle = 80, hjust = 1, margin = margin(t = -10, r = 10, b = 10, l = 10))) +
  labs(title = "Average Prices for High Alerts", y = "Average Price")

# when did it happen
# medium alert
wfp_option %>%
  left_join(med_alert, by = c("countryiso3"), 
            suffix = c("", "med_alert")) %>%
  filter(rol_avg == rol_max)

wfp_option %>%
  left_join(high_alert, by = c("countryiso3"), 
            suffix = c("", "high_alert")) %>%
  filter(rol_avg == rol_max)

### Adding summaries
# checking how many commodities are available throughout the country
total_markets <- wfp_norm %>%
  group_by(countryiso3) %>%
  summarize(total_num_markets = n_distinct(admin1, admin2, market))

commodities_all_markets <- wfp_norm %>%
  group_by(countryiso3, commodity) %>%
  summarize(num_commodities_all_markets = n_distinct(admin1, admin2, market))

proportion_all_markets <- merge(total_markets, commodities_all_markets, by = "countryiso3")
proportion_all_markets$proportion = proportion_all_markets$num_commodities_all_markets / proportion_all_markets$total_num_markets
range(proportion_all_markets$proportion)
ggplot(data = proportion_all_markets) + 
  geom_histogram(aes(proportion)) +
  labs(title = "Histogram of Proportion of Commodities available in markets across Countries")
ggplot(data = proportion_all_markets) + 
  geom_histogram(aes(proportion)) +
  labs(title = "Histogram of Proportion of Commodities available in markets across Countries") + 
  facet_wrap(vars(countryiso3))

# count for each country how many above 80% availability
proportion_all_markets %>%
  group_by(countryiso3) %>%
  summarise(sum(proportion >= 0.8))

# checking how many commodities are available throughout time
total_dates <- wfp_norm %>%
  group_by(countryiso3) %>%
  summarize(total_num_dates = n_distinct(date))

commodities_by_time <- wfp_norm %>%
  group_by(countryiso3, commodity) %>%
  summarize(num_dates = n_distinct(date))

proportion_all_dates <- merge(total_dates, commodities_by_time, by = "countryiso3")
proportion_all_dates$proportion = proportion_all_dates$num_dates / proportion_all_dates$total_num_dates
range(proportion_all_dates$proportion)
ggplot(data = proportion_all_dates) + 
  geom_histogram(aes(proportion)) +
  labs(title = "Histogram of Proportion of Commodities available across time")
ggplot(data = proportion_all_dates) + 
  geom_histogram(aes(proportion)) +
  labs(title = "Histogram of Proportion of Commodities available in markets across Countries") + 
  facet_wrap(vars(countryiso3))

# count for each country how many above 80% availability
proportion_all_dates %>%
  group_by(countryiso3) %>%
  summarise(sum(proportion >= 0.8))

# countries that do not have at least 1 commodity available throughout
countries_with_all_dates <- (proportion_all_dates %>% 
                               filter(proportion == 1) %>%
                               distinct(countryiso3))
(unique(proportion_all_dates$countryiso3))[!((unique(proportion_all_dates$countryiso3)) %in% countries_with_all_dates$countryiso3)]
# checking how often items are missing


## Checking % price increase
wfp_option2 <- wfp_norm %>%
  filter(unit_norm %in% c("KG", "L")) %>%
  group_by(countryiso3, admin1, admin2, market, date) %>%
  summarise(ave_price = mean(usdprice_norm, na.rm = TRUE)) %>%
  group_by(countryiso3, admin1, admin2, market) %>%
  arrange(countryiso3, admin1, admin2, market, date) %>%
  complete(date = seq.Date(min(date), today(), by = "month")) %>%
  mutate(
    rol_avg = zoo::rollapply(ave_price, width = 3, 
                             FUN = mean, align = "right", fill = NA),
    percent_increase = (diff(rol_avg)/lag(rol_avg)) * 100
  ) %>%
  group_by(countryiso3, date) %>%
  summarise(ave_price_inc = mean(percent_increase, na.rm = TRUE))

ggplot(data = wfp_option2) +
  geom_line(aes(x = date, y = ave_price_inc)) + 
  labs(title = "Percent Price Increase over Time",
       y = "Average Price Increase")

ggplot(data = wfp_option2) +
  geom_line(aes(x = date, y = ave_price_inc)) + 
  labs(title = "Percent Price Increase over Time",
       y = "Average Price Increase") +
  facet_wrap(vars(countryiso3))

### using commodities across most of the country and TL
wfp_option3 <- wfp_norm %>%
  filter(unit_norm %in% c("KG", "L")) %>%
  right_join(proportion_all_markets %>%
               filter(proportion >= 0.75) %>%
               select(countryiso3, commodity), 
             by = c("countryiso3", "commodity"), 
             suffix = c("", "_m")) %>%
  right_join(proportion_all_dates %>%
               filter(proportion >= 0.75) %>%
               select(countryiso3, commodity), 
             by = c("countryiso3", "commodity"), 
             suffix = c("", "_d"))

# removed some of the countries with no overlap between commodities available all over vs throughout
wfp_option4 <- wfp_option3 %>%
  group_by(countryiso3, date) %>%
  filter(!(countryiso3 %in% c("BOL", "DOM", "LKA", "SLV"))) %>%
  summarise(ave_price = mean(usdprice_norm, na.rm = TRUE)) %>%
  group_by(countryiso3) %>%
  arrange(countryiso3, date) %>%
  complete(date = seq.Date(min(date, na.rm = T), today(), by = "month")) %>%
  mutate(
    rol_avg = zoo::rollapply(ave_price, width = 3, 
                             FUN = mean, align = "right", fill = NA),
    percent_increase = (diff(rol_avg)/lag(rol_avg)) * 100
  )

ggplot(data = wfp_option4) +
  geom_line(aes(x = date, y = percent_increase)) + 
  labs(title = "Percent Price Increase over Time using most common commodities",
       y = "Average Price Increase")

# get highest value in the last year
med_alert <- wfp_option4 %>%
  filter(date >= (today() - years(1))) %>%
  group_by(countryiso3) %>%
  #filter(rol_avg == max(rol_avg, na.rm = T))
  summarise(inc_max = max(percent_increase, na.rm = T))

# plotting
ggplot(data = med_alert) +
  geom_bar(aes(x = countryiso3, y = inc_max), stat = "identity") + 
  theme(axis.text.x = element_text(angle = 80, hjust = 1, margin = margin(t = -10, r = 10, b = 10, l = 10))) +
  labs(title = "Average Price Increases for Medium Alerts", y = "Average Price")

# get highest value in the last 3 years
high_alert <- wfp_option1 %>%
  filter(date >= (today() - years(3))) %>%
  group_by(countryiso3) %>%
  #filter(rol_avg == max(rol_avg, na.rm = T))
  summarise(inc_max = max(percent_increase, na.rm = T))

#plotting
ggplot(data = high_alert) +
  geom_bar(aes(x = countryiso3, y = inc_max), stat = "identity") + 
  theme(axis.text.x = element_text(angle = 80, hjust = 1, margin = margin(t = -10, r = 10, b = 10, l = 10))) +
  labs(title = "Average Prices Increases for High Alerts", y = "Average Price")
