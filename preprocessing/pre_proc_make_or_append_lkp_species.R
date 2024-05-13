## Combine the tables into a single lkp_Speces  _ use iteration date to get this years species

lkp_species<-it_data %>% filter(iteration_date =="2023-12-21") %>%
  select(id,comment,cute_base,cute_seq,iteration_date,modeled_element,model_area)%>%
  left_join(me_data,by = join_by(modeled_element == id)) %>%
  left_join(biotics_subnational_data[c("element_subnational_id","s_primary_common_name","name_type_cd","g_rank","s_rank")],
            by = join_by(element_subnational == element_subnational_id))%>%
  left_join(model_areas_out[,c("id","comment","file_name","file_path")],by = join_by(model_area == id)) %>%
  rename(model_area_comment=comment,it_comment=comment.x, pros_notes=comment.y,
         common_name=s_primary_common_name,elem_type=name_type_cd) %>%
  mutate(cute_code=paste0(cute_base,cute_seq))%>%
  relocate(id,cute_code,cute_base,cute_seq,it_comment,iteration_date,scientific_name,common_name,
           modeled_element,element_subnational,terrestrial_or_aquatic,elem_type,
           model_area,model_area_comment,file_name,file_path,
           location_use_classes,source_feature_descriptors,g_rank,s_rank,pros_notes)

##Write it to the regular backent

#hoth_copy<-"H:\\Please_Do_Not_Delete_me\\PROS\\HOTHStuff\\HOTH_copy.db"
db_location<-"D:\\Git_Repos\\PROs\\BackEnd.sqlite"
cn <- dbConnect(SQLite(),dbname=db_location)
dbWriteTable(cn, "lkp_species", lkp_species,overwrite=TRUE)
