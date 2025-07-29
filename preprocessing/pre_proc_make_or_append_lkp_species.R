## Combine the tables into a single lkp_Speces  _ use iteration date to get this years species
##Getting the tables required for this scripts requires copying data down from the HOTH database.
##Because we are not allowed to back up that information to a public github, contact Amy Conley for help in getting these data.

library(dplyr)
library(natserv)





lkp_species<-it_data %>% filter(iteration_date =="2024-06-20") %>%
  dplyr::select(id,comment,cute_base,cute_seq,iteration_date,modeled_element,model_area)%>%
  left_join(me_data,by = join_by(modeled_element == id)) %>%
  left_join(biotics_subnational_data[c("element_subnational_id","s_primary_common_name","name_type_cd","g_rank","s_rank","element_global_seq_uid")],
            by = join_by(element_subnational == element_subnational_id))%>%
  left_join(model_areas_out[,c("id","comment","file_name","file_path")],by = join_by(model_area == id)) %>%
  rename(model_area_comment=comment,it_comment=comment.x, pros_notes=comment.y,
         common_name=s_primary_common_name,elem_type=name_type_cd) %>%
  mutate(sp_code=paste0(cute_base,cute_seq),
         nat_serve_lkup=paste0("ELEMENT_GLOBAL.2.",element_global_seq_uid),
         broad_group=NA,
         rounded_g_rank=NA,
         ModelerID=4)%>%  ##get to rounded G rank from the natserv api
        
  relocate(id,sp_code,cute_base,cute_seq,it_comment,iteration_date,scientific_name,common_name,
           modeled_element,element_subnational,terrestrial_or_aquatic,elem_type,
           model_area,model_area_comment,file_name,file_path,
           location_use_classes,source_feature_descriptors,g_rank,s_rank,pros_notes,broad_group,rounded_g_rank,ModelerID) 
  

for (i in 1:nrow(lkp_species)){
 rounded_g=ns_id(lkp_species$nat_serve_lkup[i])$roundedGRank
 lkp_species$rounded_g_rank[i]<-rounded_g
}

lkp_species<-lkp_species %>% dplyr::select(id:ModelerID)

##Write it to the regular backend

#hoth_copy<-"H:\\Please_Do_Not_Delete_me\\PROS\\HOTHStuff\\HOTH_copy.db"
db_location<-"D:\\Git_Repos\\PROs\\BackEnd.sqlite"
db_location<-"H:\\Please_Do_Not_Delete_me\\PROS\\Regional_SDM_2023\\_data\\databases\\SDM_lookupAndTracking_for_NY.sqlite"
cn <- dbConnect(SQLite(),dbname=db_location)
dbWriteTable(cn, "lkpSpecies", lkp_species,append=TRUE)

###Update the lkpEnvVars table to add HOTH_id to env
SQLquery<-"SELECT * from lkpEnvVars;"
lkp_envars <- dbGetQuery(cn, statement = SQLquery) 

names(lkp_envars)
library(dplyr)
lkp_envars<-lkp_envars %>% left_join(table_envars[,c("id","full_name","grid_name","distance_to_grid","correlated_variable_grouping")],by=c("gridName"="grid_name"))
