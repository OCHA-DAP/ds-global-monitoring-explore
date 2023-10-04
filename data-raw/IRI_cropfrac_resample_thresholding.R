#' `General Description:`
#'
#' `Objective:` using historical IRI below average forecast probabilities & land use layer - get % croplands
#' in each admin unit (admin 0 - country level for now) that are ≥ each provided threshold (30-55) across all
#' historical IRI publications and leadtimes
#'
#' `Pre-Processing:`
#'   Resample IRI Historical, ESA Crop Fraction, and FAO Crop Fraction
#'   Conditionally write out intermediate tif files at 10km resolution;
#'     1. ESA landcover classification layer masked and resampled from 10m to 500m and then downloaded here:
#'        https://code.earthengine.google.com/17ed8f69fe4caa1d2611b1d15b2094d6
#'     2. Crop fraction tifs - ESA 500 m resampled to 10 km, FAO crop fraction resampled to 10 km - tifs written to drive
#'     3. IRI tifs - 1 per pub month w/ all 4 leadtimes as individual bands resampled to 10 km
#' Once all data is resampled the IRI data is then masked w/ crop fraction layer.
#'
#' `Thresholding:`
#'   1. All resampled/masked IRI  data are put into one raster stack
#'   2. for each threshold we reclassify each item in stack to binary:
#'     a. if < threhsold --> 0
#'     b. if ≥ threshold --> 1
#'   3. we then multiply the binary stack/items in stack by crop fraction
#'   4. Run zonal sum for each country on output of step 3 - this gives total cropland ≥ threshold
#'   5. Run zonal sum on resampled cropland frac to get total cropland per country
#'   6. we can then calculate the % of cropland ≥ each threshold per country with outputs of 4 & 5

library(rgee)
library(terra)
library(tidyverse)
library(sf)
library(exactextractr)

# conditional parameters - leave as false to not write out tifs again.
write_resampled_iri <- F
write_resampled_landcover <- F

# Set Data Paths ----------------------------------------------------------

## IRI Global Tif Paths ####

fp_iri_processed <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "private",
  "processed",
  "glb",
  "iri"
)
fp_iri_tifs <- file.path(
  fp_iri_processed,
  "tif"
)

# where I will store the zonal stat results
fp_iri_zonal_output_csv <- file.path(
  fp_iri_processed,
  "iri_adm0_cropland_pct_thresholded.csv"
)


## Output for final IRI 10 km tifs ####
out_dir_iri <- file.path(
  fp_iri_tifs,
  "iri_tif_10km"
)

## Output for zonal stats


## ESA raster input ####
pub_glb_processed <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "public",
  "processed",
  "glb"
)

fp_esa_frac <- file.path(
  pub_glb_processed,
  "landcover",
  "esa_world_cover"
)

# path to codab shapefile
fp_gdb_codab <- file.path(
  pub_glb_processed,
  "cod_ab",
  "glb_drought_countries.shp"
)




## FAO Global TIFF paths ####

# should probably change folder schema to match public -- will later
fp_fao_frac <- file.path(
  Sys.getenv("AA_DATA_DIR"),
  "public",
  "raw",
  "glb",
  "cropland",
  "GlcShare_v10_02",
  "glc_shv10_02.Tif"
)


# Load CODs ---------------------------------------------------------------

cat("loading admin boundaries\n")
# topological errors in boundaries -- set this to make more flexible
sf::sf_use_s2(use_s2 = F)
st_layers(fp_gdb_codab)
gdf_adm1 <- st_read(fp_gdb_codab, layer = "glb_drought_countries.shp")
# dissolve to admin 0
gdf_adm0 <- gdf_adm1 %>%
  group_by(iso) %>%
  summarise()

# Load IRI ----------------------------------------------------------------

# IRI - just using a random 1 to set everything up first -- will batch them at the end
r_iri_template <- rast(
  list.files(fp_iri_tifs, full.names = T)[80]
)


# rename bands to lt1;4
r_iri_template %>%
  set.names(
    paste0("lt", 1:4)
  )


# Load ESA ----------------------------------------------------------------

## Load ####
# ESA crop pixel - Values: number of 10 m pixels per 500m pixel
fp_esa_cpc_500m <- list.files(
  path = fp_esa_frac,
  pattern = "*crop_frac.*500m.*.tif$",
  full.names = T
)


## ESA Merge #####
# load as Raster Collection (RC)
rc_eas_cf_500m <- terra::sprc(fp_esa_cpc_500m)

# and then merge them into a single raster
r_esa_cf_500m <- merge(rc_eas_cf_500m)


## ESA Resample - aggregate ####
cat("resamping ESA to 10km\n")
# crop to IRI bounds
r_esa_cf_500m_cropped <- crop(r_esa_cf_500m, r_iri_template)
r_esa_cf_500m_cropped %>%
  set.names("esa_cf")

# aggregation of factor of 20 gives from 500m resolution gives us 10 km res
aggregation_factor <- 20
r_esa_cf_10km <- aggregate(r_esa_cf_500m_cropped,
  fact = aggregation_factor,
  fun = mean
)


# Load FAO crop fraction --------------------------------------------------

# author of `{terra}` and `{raster}` package recommends using `exactextractr::exact_resample()`
# plus the ability to do "mean" is nice
# https://gis.stackexchange.com/questions/423291/how-can-i-both-resample-and-aggregate-a-raster-using-terra

r_fao_cf <- rast(fp_fao_frac)

# set crs
crs(r_fao_cf) <- crs(r_iri_template)

# crop to template
r_fao_cf_crop <- crop(r_fao_cf, r_iri_template)

## FAO resample to ESA ####

cat("resampling FAO to ESA \n")
# FAO to same 10 km grid as ESA is now on
r_fao_10km <- exactextractr::exact_resample(
  x = r_fao_cf_crop,
  y = r_esa_cf_10km,
  fun = "mean"
)

r_fao_10km %>%
  set.names("fao_cf")

# checks
crs(r_fao_cf) == crs(r_iri_template)
crs(r_fao_cf) == crs(r_esa_cf_10km)

# convert FAO from interger to fraction (decimal)
r_fao_10km_frac <- r_fao_10km / 100




# Write Landcover Tifs ----------------------------------------------------
# combine esa and fao crop frac

r_esa_fao_10km <- rast(
  list(r_esa_cf_10km, r_fao_10km_frac)
)

# write both resampled landcovers together as 1 tif
if (write_resampled_landcover) {
  fp_crop_fracs_out <- file.path(
    dirname(fp_esa_frac),
    "esa_fao_crop_frac_10km.tif"
  )
  writeRaster(r_esa_fao_10km, filename = fp_crop_fracs_out)
}



# so let's loop through IRI data and resample to 10 km on same grid


# Load & Resample IRI -----------------------------------------------------

cat("resampling IRI\n")
r_fnames <- list.files(fp_iri_tifs, full.names = T, pattern = "*lower_tercile.*.tif$")
r_base_fnames <- basename(r_fnames)
pub_dates <- str_extract(r_fnames, "\\d{4}-\\d{2}-\\d{2}")

r_iri_resampled <- r_fnames %>%
  map2(
    pub_dates,
    \(fn_tmp, date_tmp){
      cat(date_tmp, "\n")
      iri_tmp <- rast(fn_tmp)

      # set names
      iri_tmp %>%
        set.names(
          paste0("lt", 1:4)
        )
      ## IRI Resample ####
      r_tmp_resamp <- terra::resample(x = iri_tmp, y = r_esa_cf_10km)

      ## IRI - write resampled tif ####
      # this is just for convenience if we want rasters at any point
      if (write_resampled_iri) {
        writeRaster(
          rast(list(r_tmp_resamp, r_esa_cf_10km)),
          file.path(
            out_dir_iri,
            paste0("glb_iri_bavg_", date_tmp, ".tif")
          ),
          overwrite = T
        )
      }
      return(r_tmp_resamp)
    }
  )


# IRI threshold crop mask -------------------------------------------------

## IRI Stack ####
r_iri_all <- rast(r_iri_resampled)

## IRI - rename stack bands
all_band_names <- expand_grid(
  pub_dates,
  lt = paste0("lt_", 1:4)
) %>%
  mutate(
    band_names = paste0(pub_dates, "_", lt)
  ) %>%
  pull(band_names)

# behaves like python - renames w/ out saving as new obj
r_iri_all %>%
  set.names(all_band_names)

## Mask to FAO crops ####

# create mask
fao_crop_mask <- ifel(r_fao_10km_frac == 0, NA, r_fao_10km_frac)

# calculate total crop fraction per admin
# can use this later to calculate % cropland ≥ each threshold

fao_adm0_crop_sum <- exact_extract(
  x = fao_crop_mask,
  y = gdf_adm0,
  fun = "sum",
  append_cols = "iso"
)
# apply to all IRI bands/layers
r_iri_all_masked_fao <- mask(r_iri_all, fao_crop_mask)


## IRI threshold iteration (ADM0) ####

# define probability sequence to loop
thresh_seq_iri <- seq(30, 55, 1)

cat("starting thresholding\n")
system.time(
  ldf_thresholded <- thresh_seq_iri %>%
    map(\(thresh){
      cat("running iri threshold", thresh, "\n")

      # deep copy so no funny stuff
      r_iri_tmp <- deepcopy(r_iri_all_masked_fao)
      cat("reclassifying raster \n")

      # reclassify all rasters in stack to binary based on threshold
      # this is the part the takes a while
      cat("all values < threshold reclassify to NA\n")
      r_iri_tmp[r_iri_tmp < thresh] <- NA

      cat("all values ≥ threshold make 1\n")
      r_iri_tmp[!is.na(r_iri_tmp)] <- 1
      r_iri_crop_frac <- r_iri_tmp * fao_crop_mask

      # run zonal stats
      cat("zonal stats\n")
      df_zstats <- exact_extract(r_iri_crop_frac,
        y = gdf_adm0,
        fun = "sum",
        append_cols = "iso"
      )

      ret <- df_zstats %>%
        pivot_longer(-"iso") %>%
        separate(name,
          into = c("stat", "date"),
          sep = "\\."
        ) %>%
        separate(
          date,
          into = c("date", "leadtime"),
          sep = "_lt_"
        ) %>%
        mutate(
          threshold = thresh
        ) %>%
        rename(
          crop_gte = "value"
        ) %>%
        left_join(
          fao_adm0_crop_sum %>%
            rename(total_crop = "sum"),
          by = "iso"
        ) %>%
        mutate(
          pct_gte_thresh = crop_gte / total_crop
        )

      return(ret)
    })
)

df_zstats_thresholded <- bind_rows(ldf_thresholded)
write_csv(
  df_zstats_thresholded,
  fp_iri_zonal_output_csv
)
