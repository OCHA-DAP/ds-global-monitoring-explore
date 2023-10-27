#' **Title:** df_global_iriForecast_asapPhen.R
#' Date: 2023-10-18
#' **General Description:** 
#' This script combines all historical IRI forecast data w/ all ASAP Phenology at the single global strata level 
#' and outputs the results to tabular format.
#' **General Purpose** Once the data is combined in tabular format it will be more efficient
#' to experiment w/ thresholds and test performance
#' **Main steps:**
#'   Step 1. create unique id for each IRI pixel - convert to a polygon grid
#'   Step 2. Aggregate %  active season data to each IRI poly grid
#'   Step 3. Extract all historical IRI value (with grid ID)
#'   Step 4. Merge extracted IRI and ASAP active season data by grid ID & season
#'   Next Steps: once w decide on additional strata for analysis we can combine the polygon grid and the
#'               new strata polygon.
#' 
#' 
#' Note - to run in background:navigate to project root directory and run:
#'   caffeinate -i -s Rscript data-raw/Global_IRI_Historical_ASAP_active.R



# We initially ran this analysis using phenology data converted to binary using "End of Season" (EOS) as the definition
# for ending the active season. We later decided it would be good to use "Senescence" (SEN) to create this rasters
# Therefor, I can make this script flexible to take either raster input by just allowing the analyst to choose which set of rasters to use as input
# all this does is change a single file path.

phenology_data_definition <- c(
  "EOS",
  "SEN"
)[2]


# let user define what outputs to write, or rather just store in memory for testing
write_grid <- c(T,F)[2] # already wrote this out

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
  paste0("Global_IRI_Historical_ASAP_active_",
         phenology_data_definition,".parquet")
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

dir_phen_base <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "public",
  "processed",
  "glb",
  "asap",
  "season")

if(phenology_data_definition=="EOS"){
  dir_phen <-  file.path(
    dir_phen_base,
    "trimester_any"
  ) 
}

if(phenology_data_definition=="SEN"){
  dir_phen <-  file.path(
    dir_phen_base,
    "trimester_any_sen"
  ) 
}


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
  list.files(dir_phen,full.names = T),
)

# a nice name lookup table for renaming raster bands
# it's more complicated than necessary, but gives us a couple options for flexibility
df_phen_lookup <- tibble(
  file_name = names(r_phen_m3),
  mo_combo = str_extract_all(file_name, pattern = "\\d+-\\d+-\\d+") %>% 
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
    # For the purpose code it's simpler just to take the
    # starting month
    df_phen_lookup$mo1
  )

# make copy for removing phenology quality flag values
r_phen_qf_rm <-  deepcopy(r_phen_m3)

# FYI - this step takes a couple minutes
r_phen_qf_rm[r_phen_qf_rm>1] <- NA

# check
plot(r_phen_qf_rm[[1]]) # good


# Grid --------------------------------------------------------------------

# grab all the original IRI tif filenames (fn)
fp_iri <- list.files(dir_iri,
                     pattern = "^glb.*.tif$",
                     recursive = F,
                     full.names = T)

# take the latest one to use as a template
r_iri_template <- rast(file.path(
  fp_iri[length(fp_iri)]
))

# IRI has overlapping pixels as edges are aligned to 0.5 degs - therefore can't easily make grid - so let's crop
# to all areas of world to circumvent this issue.

world_bbox <- gdf_adm0 %>% 
  st_bbox() %>% 
  st_as_sfc()

r_iri_template_cropped <- crop(r_iri_template,
                               world_bbox)


# create grid_id band for raster
r_iri_template_cropped$grid_id <- 1:ncell(r_iri_template_cropped)

# isolate grid_id band as new raster
r_iri_grid <-  r_iri_template_cropped$grid_id

# for Global analysis I could simply aggregate ASAP phenology binary rasters
# to the IRI resolution by count, but let's create a polygon grid as it will be 
# easier to use later when we want more strata (i.e splitting strata)

# convert to polygon
poly_iri_grid<- as.polygons(r_iri_grid) %>% 
  st_as_sf()  

# write grid to shared folder v- in case it's useful for later
if(write_grid){
  st_write(
    poly_iri_grid,
    fp_output_grid
  )
}

# GET ASAP Values to grid 
# 2 minutes
system.time(
  df_phen_grid <- exact_extract(x= r_phen_qf_rm,
                                y= poly_iri_grid,
                                
                                #In all of the summary operations, NA values in the the primary raster (x) 
                                # raster are ignored (i.e., na.rm = TRUE.) ,
                                
                                fun = c("mean","count","sum"), # mean will calculate % active 
                                append_cols = "grid_id"
  )
  
)


# just quickly look at results
df_phen_grid %>% nrow()

df_phen_grid_active_polys <- df_phen_grid %>% 
  filter(
    if_any(
      starts_with("mean"),
           ~!is.nan(.x))
    ) 

df_phen_grid_active_polys %>% 
  nrow()

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


df_phen_grid_long <- df_phen_grid_active_polys %>% 
  pivot_longer(-grid_id) %>% 
  # pivot_longer(-matches("adm")) %>%
  separate(name,
           into = c("stat", "date"),
           sep = "\\."
  ) %>% 
  rename(
    start_mo_lab  = "date"
  )



# Extract IRI values ------------------------------------------------------

r_iri_historical <- rast(fp_iri)

# useful lookup for renaming bands which are not default read-in values are not useful
band_meta_lookup <- expand_grid(
  tif_name = basename(sources(r_iri_historical)),
  leadtime = c(1:4),
  ) %>% 
  mutate(
    pub_date = str_extract(tif_name, "\\d{4}-\\d{2}-\\d{2}") ,
    band_id = paste0(pub_date, "_",leadtime)
  )
length(band_meta_lookup$tif_name) == nlyr(r_iri_historical) # check

# reset band names w/ lookup table vector
r_iri_historical %>% 
  set.names(
    band_meta_lookup$band_id
  )

# crop all historical layers to world_bbox together
r_iri_historical_cropped <- crop(r_iri_historical,world_bbox)

# add grid id band
r_iri_historical_cropped$grid_id <- 1:ncell(r_iri_historical_cropped)

# extract all band values
df_iri_historical_values <- r_iri_historical_cropped %>% 
  values() %>% 
  data.frame() %>%
  tibble() 

df_iri_historical_long <- df_iri_historical_values %>% 
  # only keep grid cells that are not all NA for phenology
  filter(grid_id %in% df_phen_grid_active_polys$grid_id) %>% 
  pivot_longer(-grid_id, values_to = "iri_prob_bavg") %>% 
  mutate(
    pub_date_tmp= str_extract(name, "\\d{4}.\\d{2}.\\d{2}") ,
    leadtime = as.numeric(str_extract(name,"\\d{1}$")),
    pub_date = floor_date(as_date(pub_date_tmp,format = "%Y.%m.%d"),"month"),
    start_mo = pub_date+ months(leadtime),
    start_mo_lab = month(start_mo,label=T)
    ) %>% 
  select(-ends_with("_tmp"),-name)

df_iri_historical_asap_long <- df_iri_historical_long %>% 
  left_join(
    df_phen_grid_long %>% 
      pivot_wider(
        names_from = "stat",
        values_from = "value"
      ), by = c("grid_id","start_mo_lab")
  )

if(write_merged_tabular_data){
  write_parquet(x = df_iri_historical_asap_long,
                       sink = fp_output_merged_tab,
                       compression = "snappy") 
}
