library(rgee)
library(terra)
library(tidyverse)
ee_Initialize(gcs=TRUE)

fp_iri_tifs <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "private",
  "processed",
  "glb",
  "iri"
  ,"tif"
) 

# land use - land cover directory
fp_lulc <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "public",
  "processed",
  "glb",
  "esa_world_cover"
)

# split into multiple files
fp_lulc_tif <- list.files(path = fp_lulc,pattern = "*.tif$",full.names = T)
rc_lulc <- terra::sprc(fp_lulc_tif)
r_lulc <- merge(rc_lulc)


r_iri <- rast(
    list.files(fp_iri_tifs,full.names = T)[80]
  )


r_iri %>% 
  set.names(
    paste0("lt",1:4)
  )

r_lulc_cropped <- crop(r_lulc,r_iri)

r_lulc_cropped %>% 
  set.names("crop_pixels")

r_iri_resample <- terra::resample(x = r_iri,y = r_lulc_cropped)

target_resolution <- 1000
# Use the resample function with the 'sum' aggregation method
resampled_raster <- resample(r_lulc_cropped, fact=target_resolution,method="sum")


# not what we want
#r_fprecip_crop <- merge(r_iri_resample,r_lulc_cropped)
r_fprecip_crop %>% 
  object.size()

r_fprecip_crop <- rast(list(r_iri_resample,r_lulc_cropped))
r_fprecip_crop %>% 
  terra::writeRaster(filename = "202309_iri_croplands.tif")

gc()



# raster list - pixel ≥ thresh
rl_pixels_gte_thresh<- c(34:55)%>%  # loop through thresholds
  map(
    \(thresh_prob){
      
      # print thresh temp so we can see progress
      cat(thresh_prob,"\n")
      
      # start w/ a fresh copy of resampled IRI raster everytime
      r_iri_resample_copy <- r_iri_resample
      
      cat("making values < threshold NA\n")
      r_iri_resample_copy[r_iri_resample_copy<thresh_prob]<-NA
      
      cat("making all other values 1\n")
      r_iri_resample_copy[!is.na(r_iri_resample_copy)]<-1
      
      cat("multiplying by crop pixel raster\n")
      r_pixels_cropland_gte_thresh <- r_iri_resample_copy*r_lulc_cropped
      
      cat("finished\n")
      return(r_pixels_cropland_gte_thresh)
    }
    )

r_iri_crop <- crop(r)
r_iri_crop*rc_lulc[1]

r_iri_resample <- terra::resample(x = r_iri_crop,y = r_lulc[1])
test <- r_iri_resample * rc_lulc[1]


object.size(test)


assetId <- sprintf("%s/%s",ee_get_assethome(),'raster_l7')
rgee::raster_as_ee(x = r,assetId = "test123")
  
fp_r_upload <- list.files(fp_iri_tifs,full.names = T)[2]
assetId <-  sprintf("%s/%s",ee_get_assethome(),basename(fp_r_upload))

ee_Initialize(gcs= T)
# Method 2 - trying method 2
ee_stars_02 <- raster_as_ee(
  x = fp_r_upload,
  overwrite = TRUE,
  assetId = assetId,
  bucket = "rgee_dev"
)

#  this apparently worked
# "users/zackarno/raster_l7"
ee_stars_02 <- raster_as_ee(
  x = fp_r_upload,
  overwrite = TRUE,
  assetId = assetId,
  bucket = "ee_general_bucket"
)


# install.packages("googleCloudStorageR")
