library(rgee)
library(terra)
library(tidyverse)
library(sf)
# ee_Initialize(gcs=TRUE)

batch_process <- T
write_resampled_rasters <- T
# Set Data Paths ----------------------------------------------------------

## IRI Global Tif Paths #### 

fp_iri_tifs <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "private",
  "processed",
  "glb",
  "iri"
  ,"tif"
) 


## Output for final IRI 10 km tifs ####
out_dir_iri <- file.path(
  fp_iri_tifs,
  "iri_tif_10km"
)

## ESA raster input ####
pub_glb_processed <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "public",
  "processed",
  "glb")

fp_esa_frac <- file.path(
  pub_glb_processed,
  "landcover",
  "esa_world_cover"
)
fp_gdb_codab <- file.path(
  pub_glb_processed,
  "cod_ab",
  "glb_drought_countries.shp"
  )

gdf_adm0 <-  st_read(fp_gdb_codab)

## FAO Global TIFF paths ####

# should probably change folder schema to match public -- will later
fp_fao_frac <- file.path(Sys.getenv("AA_DATA_DIR"),
                         "public",
                         "raw",
                         "glb",
                         "cropland",
                         "GlcShare_v10_02",
                         "glc_shv10_02.Tif")



# Load IRI ----------------------------------------------------------------

# IRI - just using a random 1 to set everything up first -- will batch them at the end
r_iri_template <- rast(
  list.files(fp_iri_tifs,full.names = T)[80]
)


# rename bands to lt1;4
r_iri_template %>% 
  set.names(
    paste0("lt",1:4)
  )


# ESA ----------------------------------------------------------------

## Load ####
# ESA crop pixel - Values: number of 10 m pixels per 500m pixel
fp_esa_cpc_500m <- list.files(
  path = fp_esa_frac,pattern = "*crop_frac.*500m.*.tif$",
  full.names = T)


# load as Raster Collection (RC)
rc_eas_cf_500m <- terra::sprc(fp_esa_cpc_500m)
# rc_esa_cpc_500m <- terra::sprc(fp_esa_cpc_500m)

# and then merge them into a single raster
# r_esa_cpc_500m <- merge(rc_esa_cpc_500m)
r_esa_cf_500m <- merge(rc_eas_cf_500m)


## ESA Resample - aggregate ####
r_esa_cf_500m_cropped <- crop(r_esa_cf_500m,r_iri_template)
r_esa_cf_500m_cropped %>% 
  set.names("esa_cf")


# aggregation of factor of 20 gives from 500m resolution gives us 10 km res
aggregation_factor <- 20
r_esa_cf_10km <- aggregate(r_esa_cf_500m_cropped, 
                           fact = aggregation_factor,
                           fun = mean)


# Load FAO crop fraction --------------------------------------------------

# author of `{terra}` and `{raster}` package recommends using `exactextractr::exact_resample()`
# plus the ability to do "mean" is nice
# https://gis.stackexchange.com/questions/423291/how-can-i-both-resample-and-aggregate-a-raster-using-terra

r_fao_cf<- rast(fp_fao_frac)

# set crs
crs(r_fao_cf) <- crs(r_iri_template)

r_fao_cf_crop <- crop(r_fao_cf,r_iri_template)

# resample FAO to same 10 km grid as ESA is now on
r_fao_10km <- exactextractr::exact_resample(
  x = r_fao_cf_crop,
  y=r_esa_cf_10km, 
  fun="mean"
  )

r_fao_10km %>% 
  set.names('fao_cf')

crs(r_fao_cf)==crs(r_iri_template)
crs(r_fao_cf)==crs(r_esa_cf_10km)

# convert to decimal frac
r_fao_10km_frac <- r_fao_10km/100


Data/public/raw/


# combine esa and fao crop frac
r_esa_fao_10km <- rast(
  list(r_esa_cf_10km,r_fao_10km_frac)
  )

# write output
fp_crop_fracs_out <- file.path(
  dirname(fp_esa_frac),
  "esa_fao_crop_frac_10km.tif"
)


if(write_outputs=T){
  writeRaster(r_esa_fao_10km,filename = fp_crop_fracs_out)  
}


# We have required ESA & FAO crop fracs at 10 km now

# so let's loop through IRI data and resample to 10 km on same grid 

if(batch_process & write_outputs){
  iri_filenames <- list.files(fp_iri_tifs,full.names = T,pattern = "*lower_tercile.*.tif")
  iri_basefilenames <- basename(iri_filenames)
  pub_dates <- str_extract(iri_basefilenames,"\\d{4}-\\d{2}-\\d{2}")
  r_iri_all <- rast(iri_filenames)
  
  r_fnames <- list.files(fp_iri_tifs,full.names = T,pattern = "*lower_tercile.*.tif")
  r_base_fnames <- basename(r_fnames)
  pub_dates <- str_extract(r_fnames,"\\d{4}-\\d{2}-\\d{2}")
  
  r_fnames %>% 
    map2(pub_dates,
         \(fn_tmp,date_tmp){
           cat(date_tmp,"\n")
           iri_tmp <- rast(fn_tmp)
           
           #set names
           iri_tmp %>% 
             set.names(
               paste0("lt",1:4)
             )  
           
           r_tmp_resamp <- terra::resample(x = iri_tmp,y = r_esa_cf_10km)
           
           writeRaster(
             rast(list(r_tmp_resamp,r_esa_cf_10km)),
             file.path(
               out_dir_iri,
               paste0("glb_iri_bavg_",date_tmp,".tif")
             ),
             overwrite=T
           )
         }
    )
  
  
}




