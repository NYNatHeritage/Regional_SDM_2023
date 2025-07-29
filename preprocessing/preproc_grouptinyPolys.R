# File: preproc_grouptinyPolys.r
# Purpose: If we are working with observation data (not EO data), at least in part
#  then the observations need to be grouped spatially. 
#  
#  This script assumes these clean up tasks are already done:
#   - clean points/polys to make sure they are checked and cleaned with respect to
# - range (as defined by HUC ranges)
# - the chosen date threshold
# - appropriate precision/accuracy
# - appropriate type for appropriate species (e.g. only polys for G1, G2 if enough of them)
# point layer needs OBSDATE SPECIES_CD, and, ideally Accuracy fields. 
# poly layer needs OBSDATE SPECIES_CD, RA, Group_id
# assumption: poly shp is named cutecode.shp; pt shapefile is named cutecode_pt.shp

library(sf)
library(dplyr)
library(RSQLite)
library(here)

loc_scripts <- here()

### get a correct crs, to apply to get correct projections
#x <- st_read(paste0(loc_scripts,"/_data/other_spatial/feature/US_States.shp"))
#crs_aea <- st_crs(x)
#st_crs(x) <- "EPSG:5070" 

# this is the standard NAD83 Albers projection we are using
crs_aea <- "EPSG:26918"

# observation data
path <- paste0(loc_scripts,"/_data/occurrence")
setwd(path)

# get a list of files
x <- list.files(path,pattern=".gpkg")
# strip file extension
x <- sub(".gpkg","",x)
# remove onces I've done
for (i in 1:nrow(lkp_species)){
  cutebase<-lkp_species$cute_base[i]
  outcutecode<-paste0(lkp_species$cute_base[i],as.character(lkp_species$cute_seq[i]))
  out_iter<-lkp_species$id[i]
  print(paste(cutebase, outcutecode,out_iter))
  cutecode<-grep(cutebase,x,value=TRUE)
  print(cutecode)
}

#x <- x[6:length(x)]
cclist <- x
#cutecode <- "bromnott2"
tiny_poly_list<-character()
nrow(lkp_species)
#for(cutecode in cclist){
for (i in 3:nrow(lkp_species)){
  cutebase<-lkp_species$cute_base[i]
  outcutecode<-paste0(lkp_species$cute_base[i],as.character(lkp_species$cute_seq[i]))
  out_iter<-lkp_species$id[i]
  print(paste(cutebase, outcutecode,out_iter))
  cutecode<-grep(cutebase,x,value=TRUE)
  print(cutecode)  
  
  
  
  #desiredCols <- c("species_cd","obsdate", "accuracy")
  desiredPolyCols <- c("uid","group_id","species_cd","ra","obsdate","iter_id","elem_id","sname","scomname")
  
  # initialize in case repeatedly running
  havePolyData <- FALSE
  havePointData <- FALSE
  dataInGpkg <- FALSE
  gpkg_havePol <- FALSE
  gpkg_havePt <- FALSE
  
  ## set up for geopackage
  ## assumptions: geopackage is named with cutecode
  # inside geopackage, points layer is cutecode_pt; poly layer is cutecode
  # this is the same assumption as shapefiles (cutecode_pt.shp and cutecode.shp)
  
  if(file.exists(paste0(cutecode,".gpkg"))){
    pol_lyr <- c(paste0(cutecode,".gpkg"), cutecode)
    pt_lyr <- c(paste0(cutecode,".gpkg"), paste0(cutecode, "_pt"))
    dataInGpkg <- TRUE
    gpkg_havePol <- pol_lyr[[2]] %in% st_layers(pol_lyr[[1]])$name
    gpkg_havePt <- pt_lyr[[2]] %in% st_layers(pt_lyr[[1]])$name
  } else {
    pol_lyr <- c(NA,paste0(cutecode, ".shp"))
    
  }
  
  # check for and load poly data
  
  if(file.exists(pol_lyr[[2]]) | gpkg_havePol){
    if(dataInGpkg){
      pol <- st_read(pol_lyr[[1]], pol_lyr[[2]], stringsAsFactors = FALSE)
    } else {
      pol <- st_read(pol_lyr[[2]], stringsAsFactors = FALSE)    
    }
    
    pol_dat <- st_transform(pol, crs_aea)
    if(nrow(pol_dat) > 0 ){
      havePolyData <- TRUE  
    }
    
    geomName <- attr(pol_dat, "sf_column")
    names(pol_dat)[!names(pol_dat) == geomName] <- tolower(names(pol_dat)[!names(pol_dat) == geomName])
    pol_dat <- pol_dat[,c(desiredPolyCols,geomName)]
    # check for bad polys
    if(FALSE %in% st_is_valid(pol_dat)){
      pol_dat <- st_make_valid(pol_dat)
    }
    # drop z dim
    pol_dat <- st_zm(pol_dat)
  }
  
  # check for tiny poly in poly data
  tiny_poly<-pol_dat %>% mutate (area_m2=as.numeric(st_area(geom))) %>%filter(area_m2 <900)
    if(nrow(tiny_poly) > 0 ){
      havetinyPolys <- TRUE  
      tiny_poly_list<-append(tiny_poly_list,cutecode)
      print(paste0(cutecode," has ",nrow(tiny_poly)," tiny polys out of ",nrow(pol_dat)))
    }
#}  ##Stop here just to count the polys and not do the buffering
    regular_polys<- pol_dat %>% mutate (area_m2=as.numeric(st_area(geom))) %>%filter(area_m2 >=900)
  
  # process data given three options: points and polys, points only, polys only
  if(havetinyPolys){
    # double check units
    #st_crs(pt_dat)$units 
    print(paste0(cutecode," has tiny polys! Need to buffer them before putting in points"))
    # convert pts to polys
    # assume that actual point may have some accuracy issues so 
    # make large enough to include closest adjacent cells
    #dat_eo <- st_buffer(dat_grps, 90)
    # buffer 22 meters. This ensures that tiny polys within the same 30 meter pixel will overlap creating a larger blob that will reduce pseudorep
    ptd_pol <- st_buffer(tiny_poly, dist = 22)
    # merge overlapping polys
    ptd_pol_m <- st_union(ptd_pol, by_feature = FALSE)
    # convert to single-part, add attribute table
    ptd_pol_m = st_cast(ptd_pol_m, "POLYGON")
    ptd_df <- data.frame("pol_id" = c(1:length(ptd_pol_m)))
    ptd_pol_m <- st_set_geometry(ptd_df, ptd_pol_m)
    
    # get back date (using the most recent obs date for each polygon)
    ptp_j <- st_join(ptd_pol_m, ptd_pol[,c("obsdate","group_id" ,"species_cd","iter_id","elem_id","sname","scomname")], join = st_intersects, left = TRUE)
    ptp_a <- aggregate(ptp_j, by = list(ptp_j$pol_id), FUN = function(x){ max(x)})
    geomName <- attr(ptp_a, "sf_column")
    ptp <- ptp_a[,c("pol_id","obsdate","group_id" ,"species_cd","iter_id","elem_id","sname","scomname",geomName)]
    ptp <- cbind(ptp, RA = "Very High")
    
    # Buffer by those units (m) to get group based on separation distance ("EO"), merge them
    # 500 meter default (means 1km sep distance)
    pt_buff1km <- st_buffer(ptp, 500)
    pt_grps <- st_union(pt_buff1km, by_feature = FALSE)
    
    # convert to single-part, add attribute table
    pt_grps = st_cast(pt_grps, "POLYGON")
    ptdf <- data.frame("group_id" = c(1:length(pt_grps)))
    pt_grps <- st_set_geometry(ptdf, pt_grps)
    
    # attribute points with group ID
    ptd_grps <- suppressWarnings(st_intersection(ptp, pt_grps))
    table(ptd_grps$group_id)
    
    geomName <- attr(ptd_grps, "sf_column")
    ptd_grps<-ptd_grps %>% dplyr::select(pol_id,group_id,species_cd,RA,obsdate,iter_id,elem_id,sname,scomname,paste0(geomName))
    names(ptd_grps) <- c("UID","GROUP_ID","SPECIES_CD","RA","OBSDATE","iter_id","elem_id","SNAME","SCOMNAME",geomName)
    
    if(nrow(regular_polys) >0){
      ## have tiny polys and regular polys
      ##join them back
      regular_polys<-regular_polys %>% dplyr::select(!area_m2)
      geomName <- attr(regular_polys, "sf_column")
     
      names(regular_polys)<-c("UID","GROUP_ID","SPECIES_CD","RA","OBSDATE","iter_id","elem_id","SNAME","SCOMNAME",geomName)
      st_geometry(regular_polys)<-"geometry"
      # merge the pt and poly data sets
      # it's possible the geometry columns are named differently. Ensure they are the same
      #regular_polys = st_sf(st_set_geometry(regular_polys, NULL), geometry = st_geometry(regular_polys))
      #ptd_grps = st_sf(st_set_geometry(ptd_grps, NULL), geometry = st_geometry(ptd_grps))
      
      dat_all <- rbind(regular_polys, ptd_grps)
      dat_all<-dat_all %>% arrange(GROUP_ID) %>% mutate(UID = row_number())
      
      # st_is_valid(dat_all)
      # st_is_valid(ptd_grps)
      # st_is_valid(pol_dat)
      # dat_all <- st_make_valid(dat_all)
      # dat_all <- st_buffer(dat_all, dist = 0)
      
      # remove overlapping polygons by merging
      dat_all_m <- st_union(dat_all, by_feature = FALSE)
      # convert to single-part, add attribute table
      dat_all_sp = st_cast(dat_all_m, "POLYGON")
      dadf <- data.frame("UID" = c(1:length(dat_all_sp)))
      dat_all_sp <- st_set_geometry(dadf, dat_all_sp)
      
      # TODO: polys could have custom group designations (not based on a standard sep distance)
      # stick with 1km sep distance for now (500 m buff)
      # Drop this since EOID is already included
      #py_buff1km <- st_buffer(dat_all_sp, 500)
      #py_grps <- st_union(py_buff1km, by_feature = FALSE)
      
      # convert to single-part, add attribute table
      #py_grps = st_cast(py_grps, "POLYGON")
      #pydf <- data.frame("GROUPID" = c(1:length(py_grps)))
      #py_grps <- st_set_geometry(pydf, py_grps)
      
      # attribute original polys with group ID
      #py_grps <- suppressWarnings(st_intersection(py_grps, dat_all_sp))
      #table(py_grps$GROUP_ID)
      
      # get back date (using the most recent obs date for each polygon)
      pyp_j <- st_join(dat_all_sp, dat_all[,c("GROUP_ID","SPECIES_CD","RA","OBSDATE","iter_id","elem_id","SNAME","SCOMNAME")], join = st_intersects, left = TRUE)
      pyp_a <- aggregate(pyp_j, by = list(pyp_j$UID), FUN = function(x){ max(x)})
      geomName <- names(pyp_a)[length(names(pyp_a))]
      pyp <- pyp_a[,c("UID","GROUP_ID", "SPECIES_CD","RA","OBSDATE","iter_id","elem_id","SNAME","SCOMNAME",geomName)]
      
      pyp<-pyp %>% mutate(iter_id=out_iter,SPECIES_CD=outcutecode)
      # move the existing (point and poly) files to the pre-processed folder
      filesToMove <- list.files(pattern = cutecode)
      file.copy(from = filesToMove, to = paste0("pre-processed/",filesToMove))
      print("Moving original data to pre-processed and writing merged data to gpkg")
      # write out the merged, all-poly layer
      # this doesn't necessarily open in arcgis
      dsnNm <- paste0(outcutecode,".gpkg")
      lyrNm <- outcutecode
      st_write(pyp, dsn = dsnNm, layer = lyrNm, driver = "GPKG",overwrite=TRUE,append=FALSE)
      # shapefile version
      #fullnm <- paste0(cutecode,".shp")
      #st_write(pyp, fullnm)
    } else {
      ## all polys are tiny so just write out the buffered tiny
      # move the existing (point and poly) files to the pre-processed folder
      
      ptd_grps<-ptd_grps %>% mutate(iter_id=out_iter,SPECIES_CD=outcutecode)
      print("Only tiny polys write out new buffered!")
      filesToMove <- list.files(pattern = cutecode)
      file.copy(from = filesToMove, to = paste0("pre-processed/",filesToMove))
      
      # write out the layer
      dsnNm <- paste0(outcutecode,".gpkg")
      lyrNm <- outcutecode
      st_write(ptd_grps, dsn = dsnNm, layer = lyrNm, driver = "GPKG",append=FALSE)
      
      # write out the merged, all-poly shapefile
      # fullnm <- paste0(cutecode,".shp")
      # st_write(ptd_grps, fullnm)
    }
  } else {
    ## have poly data only 
    # don't need to do anything!
    print("No tiny polys! Use AS-IS")
  }
  
}  
