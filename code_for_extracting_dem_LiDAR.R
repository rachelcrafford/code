
## This script outlines the workflow for deriving vegetation structure metrics from LiDAR datasets. 

# Install and load the required packages
install.packages("lidR")
library(lidR)
install.packages("terra")
library(terra)
install.packages("raster")
library(raster)
install.packages("sf")
library(sf)
install.packages("dplyr")
library(dplyr)
install.packages("future")
library(future)

## Set working directory
setwd("G:/My Drive/GMUG_LiDAR/data")

#############################################

## Loading and preparing data

# Load in GMUG shapefile 
gmug <- st_read("G:/.shortcut-targets-by-id/18KzRJgC9b5miNvjWohrVBh1U8Mq9tdVP/GMUG_LiDAR/data/masks/gmug3.shp")

# Choose a specific variable to keep
Shape_Area <- "Shape_Area"
gmug <- gmug[, "Shape_Area", drop = FALSE]

# Load in Raster Template

raster_template_3m <- rast("G:/.shortcut-targets-by-id/18KzRJgC9b5miNvjWohrVBh1U8Mq9tdVP/GMUG_LiDAR/data/masks/GB_mask_3m_v1.tif")
crs(raster_template_3m)

# Load in LiDAR point cloud data 

mesa <- readLAScatalog("G:/.shortcut-targets-by-id/18KzRJgC9b5miNvjWohrVBh1U8Mq9tdVP/GMUG_LiDAR/data/mesa6/")

# Check and display the CRS of the LiDar catalog and the polygon
st_crs(mesa)
st_crs(gmug)

# If the CRS doesn't match, re-project one of them to the other's CRS
gmug <- st_transform(gmug, st_crs(mesa))

# Clip LAS files to GMUG extent 
mesa <- catalog_intersect(mesa, gmug) 

# Check out the clip to ensure that the LAS files overlap our area of interest
plot(mesa)
plot(gmug, add=TRUE, col=rgb(0.7,0.5,0.5,0.5))


## Preprocessing our data

# Catalog engine processes by "chunks", which might not be the same as the underlying files.
opt_chunk_size(mesa) <- 1000
opt_chunk_buffer(mesa) <- 30 # space around tile edges
opt_stop_early(mesa) <- FALSE
opt_output_files(mesa) <- ("G:/.shortcut-targets-by-id/18KzRJgC9b5miNvjWohrVBh1U8Mq9tdVP/GMUG_LiDAR/scratch/chunks/chunk_{ID}")


# Sets catalog to overwrite outputs by default.
mesa@output_options$drivers$Raster$param$overwrite <- TRUE

## Defining custom metrics and processing functions

# Custom catalog processing function.
myfun <- function(chunk,template_path="G:/.shortcut-targets-by-id/18KzRJgC9b5miNvjWohrVBh1U8Mq9tdVP/GMUG_LiDAR/data/masks/GB_mask_3m_v1.tif") {
  set_lidr_threads(1L)
  # Load the chunk + buffer
  las <- readLAS(chunk) 
  if (is.empty(las)) return(NULL)
  
  # New function to re-project LiDAR point cloud
  raster_template_3m <- rast(template_path)
  las_reproj <- sf::st_transform(las, st_crs(raster_template_3m))
  
  # Process DEM
  dem <- grid_terrain(las_reproj,use_class=2,res=3,
                      algorithm=tin())

  return(dem)
}

# Runs function on catalog
plan(multisession, workers = 8L)
mesa_dem <- catalog_apply(mesa, myfun)

## Export raster

# Convert list elements to SpatRaster
rast_list <- list()
for (i in 1:length(mesa_dem)) {
  rast_list[[i]] <- rast(mesa_dem[[i]])
}

# Create spat raster collection 
mesa_sprc <- sprc(rast_list)

# Merge spat rasters
mesa_mos <- merge(mesa_sprc)
plot(mesa_mos)

# Save to disk
writeRaster(mesa6tiles_mos, filename = 'G:/.shortcut-targets-by-id/18KzRJgC9b5miNvjWohrVBh1U8Mq9tdVP/GMUG_LiDAR/deliverables/DEMs_final_8.5.24/mesadem.tif',
            overwrite=TRUE)


