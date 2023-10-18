#' **Title:** df_global_iriForecast_asapPhen.R
#' Date: 2023-10-18
#' **General Description:** 
#' This script combines all historical IRI forecast data w/ all ASAP Phenology at the single global strata level 
#' and outputs the results to tabular format.
#' **General Purpose** Once the data is combined in tabualar format it will be more effecient
#' to experiment w/ thresholds and test performance
#' **Main steps:**
#'   Step 1.
#' 
#' 
#' 
#' Note: navigate to project root directory and run:
#'   caffeinate -i -s Rscript data-raw/df_global_iri_active_thresholds.R


write_grid <- c(T,F)[1]
write_merged_tabular_data <- c(T,F)[1]

library(tidyverse)
library(sf)
library(terra)
library(exactextractr)
library(arrow)

# Load file/gdb paths -----------------------------------------------------

# define output locations/file paths
fp_output_grid <-  file.path(
  Sys.getenv("AA_DATA_DIR"),
  "private",
  "processed",
  "glb",
  "iri",
  "iri_global_grid.shp"
)
fp_output_merged_tab <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "private",
  "processed",
  "glb",
  "iri",
  "Global_IRI_Historical_ASAP_active_EOS.parquet"
)

# adm0 gdb
gdb_adm0 <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "public",
  "raw",
  "glb",
  "asap",
  "reference_data",
  "gaul0_asap_v04"
)

dir_iri <-  file.path(
  Sys.getenv("AA_DATA_DIR"),
  "private",
  "processed",
  "glb",
  "iri",
  "tif"
)


dir_phen <-  file.path(
  Sys.getenv("AA_DATA_DIR"),
  "public",
  "processed",
  "glb",
  "asap",
  "season",
  "trimester_any"
)


# Load data into memory ---------------------------------------------------

# Global admin 0
# `USE:`IRI data has overlapping pixels so is not spatially valid - therefore we will
# clip i t to the bbox of all continents to remove this issue
gdf_adm0 <- st_read(
  gdb_adm0,
  layer = "gaul0_asap"
)

# ASAP Phenology data - rasters containing binary values indicating whether or not
r_phen_m3 <- rast(
  list.files(dir_months3,full.names = T),
)

# can make nice names for extractio depending on the use
df_phen_lookup <- tibble(
  file_name = names(r_phen_m3),
  mo_combo = str_extract_all(file_name, "\\d.*") %>% 
    unlist()
) %>% 
  separate(
    mo_combo,into = c("mo1","mo2","mo3"),sep = "-"
  ) %>%
  mutate(
    across(
      starts_with("mo"),~month(as.numeric(.x),label=T)
    )  
  ) %>% 
  unite("new_name",
        starts_with("mo"),
        sep = "-",remove = F) #%>% 


r_phen_m3 %>% 
  set.names(
    # df_phen_lookup$new_name
    
    # lts simplify for this purpose
    df_phen_lookup$mo1
  )

# phenology quality flags removed
r_phen_qf_rm <-  deepcopy(r_phen_m3)

# FYI - this step takes a couple minutes
r_phen_qf_rm[r_phen_qf_rm>1] <- NA

# check
plot(r_phen_qf_rm[[1]]) # good


# Grid --------------------------------------------------------------------

# grab all the original IRI tif names
fn_iri <- list.files(dir_iri,pattern = "^glb.*.tif$",recursive = F)

# take the latest one to use as a template
r_iri_template <- rast(file.path(
  dir_iri,
  fn_iri[length(fn_iri)]
))

# IRI has overlapping pixels - therefore can't easily make grid - so let's crop
# to all areas of world to remove this problem

world_bbox <- gdf_adm0 %>% 
  st_bbox() %>% 
  st_as_sfc()

r_iri_template_cropped <- crop(r_iri_template,world_bbox)

# create grid_id band for raster
r_iri_template_cropped[["grid_id"]] <- 1:ncell(r_iri_template_cropped)

# isolate grid_id band as new raster
r_iri_grid <-  r_iri_template_cropped[["grid_id"]]

# for Global analysis I could simply aggregate ASAP phenology binary rasters
# to the IRI resolution by count, but let's create a polygon grid as it will be 
# easier to use later when we want more strata (i.e splitting strata)

# convert to polygon
poly_iri_grid<- as.polygons(r_iri_grid) 
poly_iri_grid <- poly_iri_grid %>% 
  st_as_sf()  

# write grid to shared folder
if(write_grid){
  st_write(
    poly_iri_grid,
    fp_output_grid
  )
}


# GET ASAP Values to grid 
r_phen_qf_rm[[1]] %>% plot()
poly_iri_grid$geometry %>% plot()

# 2 minutes
system.time(
  df_phen_grid <- exact_extract(x= r_phen_qf_rm,
                                y= poly_iri_grid,
                                
                                #In all of the summary operations, NA values in the the primary raster (x) 
                                # raster are ignored (i.e., na.rm = TRUE.) ,
                                
                                fun = c("mean"), # mean will calculate % active 
                                append_cols = "grid_id"
  )
  
)

# just quickly look at results
df_phen_grid_active_polys <- df_phen_grid %>% 
  filter(
    if_any(
      starts_with("mean"),
           ~!is.nan(.x))
    ) 

# lets make sure all these NA values make sense - Looks good 
poly_iri_grid %>% 
  mutate(
    active_ever = grid_id %in% df_phen_grid_active_polys$grid_id
  ) %>% 
  ggplot()+
  geom_sf(aes(fill =active_ever))


#' Note - not sure if i need the count / sum since i was just going to calculate the sum anyways
# system.time(
#   df_phen_grid <- exact_extract(x= r_phen_qf_rm,
#                                 y= poly_iri_grid,
#                                 fun = c("count", # count total pixels (0 & 1) in grid cell
#                                         "sum" # sum active pixels
#                                 ),
#                                 append_cols = "grid_id")
#   
# )

df_phen_grid %>% 
  pivot_longer(-grid_id)
  head()



# Extract IRI values ------------------------------------------------------

r_iri_historical <- rast(file.path(
  dir_iri,
  fn_iri
))

# useful lookup for renaming bands which are not default read-in values are not useful
band_meta_lookup <- expand_grid(
  tif_name = basename(sources(r_iri_historical)),
  leadtime = c(1:4),
  ) %>% 
  mutate(
    pub_date = str_extract(tif_name, "\\d{4}-\\d{2}-\\d{2}") ,
    band_id = paste0(pub_date, "_",leadtime)
  )


# reset band names w/ lookup table vector
r_iri_historical %>% 
  set.names(
    band_meta_lookup$band_id
  )

# crop all historical layers to world_bbox together
r_iri_historical_cropped <- crop(r_iri_historical,world_bbox)

# add grid id band
r_iri_historical_cropped[["grid_id"]] <- 1:ncell(r_iri_historical_cropped)

# extract all band values
df_iri_historical_values <- r_iri_historical_cropped %>% 
  values() %>% 
  data.frame() %>%
  tibble() 


df_phen_grid_long <- df_phen_grid_active_polys %>% 
  tibble() %>% 
  pivot_longer(-grid_id,values_to  = "pct_active_season") %>%
  mutate(
    start_mo_lab  = str_remove(name,"mean.")
  ) %>% 
  select(-name)


df_iri_historical_long <- df_iri_historical_values %>% 
  # only keep grid cells that are not all NA for phenology
  filter(grid_id %in% df_phen_grid_active_polys$grid_id) %>% 
  pivot_longer(-grid_id, values_to = "iri_prob_bavg") %>% 
  mutate(
    pub_date_tmp= str_extract(name, "\\d{4}.\\d{2}.\\d{2}") ,
    leadtime = as.numeric(str_extract(name,"\\d{1}")),
    pub_date = floor_date(as_date(pub_date_tmp,format = "%Y.%m.%d"),"month"),
    start_mo = pub_date+ months(leadtime),
    start_mo_lab = month(start_mo,label=T)
    ) %>% 
  select(-ends_with("_tmp"),-name)

df_iri_historical_asap_long <- df_iri_historical_long %>% 
  left_join(
    df_phen_grid_long
  )

if(write_merged_tabular_data){
  write_parquet(x = df_iri_historical_asap_long,
                       sink = fp_output_merged_tab,
                       compression = "snappy") 
}



