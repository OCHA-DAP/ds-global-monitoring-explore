# libraries

# for installing rhdx
# install.packages("remotes")
# remotes::install_gitlab("dickoa/rhdx")

library(tidyverse)
library(gghdx)
library(rhdx)
gghdx()

# rhdx config
set_rhdx_config(hdx_site = "prod")
get_rhdx_config()

# reading in the global dataset
wfp_glb <- read_csv("https://data.humdata.org/dataset/31579af5-3895-4002-9ee3-c50857480785/resource/0f2ef8c4-353f-4af1-af97-9e48562ad5b1/download/wfp_countries_global.csv")

# searching for wfp food price datasets on HDX and reading in resources
wfp_fp_datasets <- search_datasets(" - Food Prices", rows = 300) %>%
  purrr::set_names(map(., ~.x$data$title)) %>%
  subset(names(.) != "Global - Food Prices") %>%
  map(~.x %>% 
        get_resource(1) %>%
        read_resource()) 

# removing possible duplicates
wfp_fp_resources <- wfp_fp_datasets %>%
  names() %>%
  duplicated() %>%
  `!`() %>%
  wfp_fp_datasets[.]

# exploring possible thresholds
# Q1: Do different countries tend to have lower prices than others?
# Q2: Pricetype: Wholesale vs retail
# Q3: Which category/commodity is the most expensive?
# Q4: 
# Q5: 
