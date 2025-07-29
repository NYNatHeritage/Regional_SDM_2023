##This setup script will be run before SDM modeling to pull down the latest information from HOTH
##Pull all the tables
##Copy that information into a SQLLite database for easy read-Write during the modeling process
##Making fresh copies is the best compromise between the security that keeps HOTH protected and the acces
## that is necessary for reading and writing out information needed during long modeling processes that would
## otherwise be halted by the 1 hour automatic log-out.


##Step 1: Get Iterations, Modeled Elements, Model Areas, Locations, Source Feature Descriptors
library(here)
library(rvest)
library(jsonlite)
library(httr)
library(RODBC)
library(httr)

library(getPass)
library(sf)

## load functions ----
source(file.path(here(),"_custom_functions.R"))

## connect and log into HOTH ----
api_session <- hth_ConnectToAPI()


# this is actually loaded in the custom_functions, but leaving here for clarity
api_url <- "https://hoth.nynhp.org/api/"

# get a full biotics subnational elemnts from HOTH ----
biotics_subnational_url<-paste0(api_url,"biotics-subnational-elements/")
biotics_subnational_data<-hth_fullTable(api_sess = api_session, table_url = biotics_subnational_url)
# get a full list of model elements from HOTH ----
modeledElems_url <- paste0(api_url, "modeled-elements/")

me_data <- hth_fullTable(api_sess = api_session, table_url = modeledElems_url)

#keepCols <- c("id","scientific_name","comment", "terrestrial_or_aquatic",
 #             "element_subnational","location_use_classes","source_feature_descriptors")


me_data <- me_data %>% select(!(created_by:modified_at))
me_data$location_use_classes<-as.character(me_data$location_use_classes)
me_data$source_feature_descriptors<-as.character(me_data$source_feature_descriptors)

# get all model iterations ----
iterations_url <- paste0(api_url, "model-iterations/")

it_data <- hth_fullTable(api_sess = api_session, table_url = iterations_url )

it_data <-it_data %>% select(!(created_by:modified_at)) ##Drop the autofill fields fromHOTH
# get all location use classes ----
location_use_URL<-paste0(api_url,"biotics-d-location-use-classes/")
location_use_data<-hth_fullTable(api_sess = api_session, table_url = location_use_URL)

# get all source feature descriptions (how NYNHP describes locations use class) ----

sf_descriptor_url<-paste0(api_url,"d-source-feature-descriptors/")
sf_descriptor_data<-hth_fullTable(api_sess = api_session, table_url = sf_descriptor_url)

# get all model areas ----
mas_url<-"https://hoth.nynhp.org/api/model-areas/"
table_modelareas<-hth_fullTable(api_sess = api_session, table_url = mas_url )
model_areas_out<-table_modelareas %>% select(!(created_by:modified_at)) %>% arrange(id)

# get all model details----
details_url<-"https://hoth.nynhp.org/api/model-detail-records/"
table_modeldetails<-hth_fullTable(api_sess = api_session, table_url = details_url )
table_modeldetails$environmental_variables<-as.character(table_modeldetails$environmental_variables)

# get all envar HOTH details----
envars_url<-"https://hoth.nynhp.org/api/d-environmental-variables/"
table_envars<-hth_fullTable(api_sess = api_session, table_url = envars_url )

# get all algo HOTH details----
algo_url<-"https://hoth.nynhp.org/api/d-algorithms/"
table_algos<-hth_fullTable(api_sess = api_session, table_url = algo_url )




library(RODBC)
library(RSQLite)
hoth_copy<-"H:\\Please_Do_Not_Delete_me\\PROS\\HOTHStuff\\HOTH_copy.db"
db_location<-"D:\\Git_Repos\\PROs\\BackEnd.sqlite"
db <- dbConnect(SQLite(),dbname=hoth_copy)

# Connect to SQL Server
#con = dbConnect(odbc(),.connection_string = "Driver={SQL Server};Server=ipaddress;Uid=user;Pwd=password;")

# Write the table,is it doesn't exist it will be created Modeled Elements
dbWriteTable(db, "modeled_elements", me_data,overwrite=TRUE)

# Write the table,is it doesn't exist it will be created Iterations
dbWriteTable(db, "model_iterations", it_data,overwrite=TRUE)

# Write the table,is it doesn't exist it will be created Iterations
dbWriteTable(db, "model_iterations", it_data,overwrite=TRUE)

#Write the table,is it doesn't exist it will be created Location Use D
dbWriteTable(db, "location_use_descriptiors", location_use_data,overwrite=TRUE)

#Write the table,is it doesn't exist it will be created Source Feature Descriptors
dbWriteTable(db, "source_feature_descriptiors", sf_descriptor_data,overwrite=TRUE)

#Write the table,is it doesn't exist it will be created Model Areas
dbWriteTable(db, "model_areas", model_areas_out,overwrite=TRUE)

#Write the table,is it doesn't exist it will be created Model Areas
dbWriteTable(db, "biotics_subnational", biotics_subnational_data,overwrite=TRUE)

#Write the table,is it doesn't exist it will be created Model Details
dbWriteTable(db, "model_details", table_modeldetails,overwrite=TRUE)

#Write the table,is it doesn't exist it will be created Environmental Variables
dbWriteTable(db, "d_environmental_variables", table_envars,overwrite=TRUE)

#Write the table,is it doesn't exist it will be created Environmental Variables
dbWriteTable(db, "d_algos", table_algos,overwrite=TRUE)

db_location<-"H:\\Please_Do_Not_Delete_me\\PROS\\Regional_SDM_2023\\_data\\databases\\SDM_lookupAndTracking_for_NY.sqlite"
cn <- dbConnect(SQLite(),dbname=db_location)
library(dplyr)
table_algos<-table_algos %>% select(!created_by:comment)
dbWriteTable(cn, "lkpAlgorithms", table_algos,overwrite=TRUE)

table_envars<-table_envars %>% select(!created_by:modified_at)
dbWriteTable(cn, "d_environmental_variables", table_envars,overwrite=TRUE)
