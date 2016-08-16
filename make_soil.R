# CIAT - 2016 
# Project: 

# Generate the identifier for Soil using the information for Global High-Resolution Soil Profile Database
# Applications for Crop Modelintg (using a raster)

# Developer code R  e-mail: jeison.mesa@correounivalle.edu.co; j.mesa@cgiar.org
# Developer layer Soil Jawoo Koo j.koo@cgiar.org

# Citations
# 
# For Working Paper
# Han, Eunjin; Ines, Amor; Koo, Jawoo (2015) "Global High-Resolution Soil Profile Database for Crop Modeling Applications," Working Paper, HarvestChoice/International Food Policy Research Institute (IFPRI).
# 
# For Data Files
# Han, Eunjin; Ines, Amor; Koo, Jawoo, 2015, "Global High-Resolution Soil Profile Database for Crop Modeling Applications", http://dx.doi.org/10.7910/DVN/1PEEY0, Harvard Dataverse, V1 

# The following code binds the soil base to the resolution of the raster information for input


library(snowfall)
library(raster)
library(rgdal)
library(plotKML)
library(maptools)
library(dplyr)
library(stringr)
library(stringi)

## Working Drectories

path <- '//dapadfs/workspace_cluster_6/ALPACAS/Plan_Regional_de_Cambio_Climatico_Orinoquia/'

path_soil_dssat <- 'Suelos_dssat_10km/point5m_soilgrids-for-dssat-10km_v1/'

sub_dir_climate <- '01-datos_clima/datos_diarios/_dat_files/' 

path_.SOIL <- 'Suelos_dssat_10km/SoilGrids-for-DSSAT-10km v1.0 (by country)'

soils_out <- '/04-Crop_Modelling/Dssat/'

## Names ot fhe necessary files to upload

name_raster_id <- 'coords_id.tif'

## Soils wordwide 10 km2 spatial resolution

soils <- readOGR(paste0(path, path_soil_dssat, '/.'), 'point5m_soilgrids-for-dssat-10km_v1')

## id to identify the climate for each pixel 

id_raster_climate <- raster(paste0(path, sub_dir_climate, name_raster_id))

soils_ori <- crop(soils, id_raster_climate)


r <- raster(extent(soils_ori)) # creates a raster with the extent of soils_ori
projection(r) <- proj4string(soils_ori) # uses the projection of the shapefile

# for the raster    
res(r)=  0.1  ## Spatial Resolution

r10 <- rasterize(soils_ori, field = "CELL5M", r, fun = 'last')
projection(r10) <- proj4string(soils_ori)
r10 <- resample(r10, id_raster_climate, 'ngb')

### Shape file for datasets 

shape_orinoquia <- '/Cultivos EVAS, CorinLandCover/r3/'
Orinoquia <- shapefile(paste0(path, shape_orinoquia, 'Cormacarena_Munt.shp'))
Orinoquia <- spTransform(Orinoquia, '+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0')

r10 <- mask(r10, Orinoquia)
puntos <- rasterToPoints(r10)

rm(r, r10)

colnames(puntos)[3] <- 'CELL5M'
data_soils_ori <- data.frame(soils_ori)
merge_raster_soil <- inner_join(tbl_df(data.frame(puntos)), tbl_df(data_soils_ori), by = 'CELL5M')
rm(puntos, data_soils_ori)
merge_raster_soil <- merge_raster_soil[, c('x', 'y', 'CELL5M', 'SoilProfil', 'ISO2')]



files_SOIL <- list.files(paste0(path, path_.SOIL), full.names = T)

## Just upload the files necessary Soil

col_SOIL <- sort(unique(substr(merge_raster_soil$SoilProfil, 1, 2)))


orinoquia_SOIL <- grep(paste(col_SOIL, collapse="|"), files_SOIL, value = TRUE)



sfInit(parallel = T, cpus = 25) #initiate cluster

#export functions
sfSource(file = 'C:/R_Projects/DSSAT_use_Marksim/main_functions.R')

orinoquia_SOIL_text <- sfLapply(orinoquia_SOIL, fun = readLines)
sfStop()


ref_SOIL <- merge_raster_soil[!duplicated(merge_raster_soil$SoilProfil), ]
names(orinoquia_SOIL_text) <- col_SOIL



sfInit(parallel = T, cpus = 23) #initiate cluster

sfSource(file = 'C:/R_Projects/DSSAT_use_Marksim/main_functions.R')
sfExport('orinoquia_SOIL_text')
sfExport('pos_match_soil')
sfLibrary(stringi)
sfExport('ref_SOIL')

x <- sfLapply(1:dim(ref_SOIL)[1], function(i) pos_match_soil(orinoquia_SOIL_text, ref_SOIL$SoilProfil[i], ref_SOIL$ISO2[i]))


x <- unlist(x)

ref_SOIL$pos.SOIL <- x 
sfStop()



sfInit(parallel = T, cpus = 23) #initiate cluster
sfExport('orinoquia_SOIL_text')
sfExport('ref_SOIL')
sfExport('read_oneSoilFile')
sfExport('path')

orinoquia.SOIL <- sfLapply(1:dim(ref_SOIL)[1], function(i) read_oneSoilFile(orinoquia_SOIL_text, ref_SOIL$pos.SOIL[i], ref_SOIL$ISO2[i], getwd()))

names(orinoquia.SOIL) <- ref_SOIL$SoilProfil

rm(orinoquia_SOIL_text)
gc()
save(merge_raster_soil, orinoquia.SOIL, file = paste0(path, soils_out, 'SOIL_2.R'))




