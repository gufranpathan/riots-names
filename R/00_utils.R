
save_track_object <- function(object_to_save, saving_function, output_extension = "tex", output_path="data/02_output/",...){
  
  if(any(class(object_to_save)%in%c("name"))){
    object_name <- deparse(object_to_save)  
    object_to_save <- eval(object_to_save,envir = parent.frame())
  }else{
    object_name <- deparse(substitute(object_to_save))
  }
  path_to_save <- paste0(output_path,object_name,".",output_extension)
  
  if(deparse(substitute(saving_function))=="ggsave"){
    # print("In GGsave")
    # print(saving_function)
    # print(path_to_save)
    saving_function(filename=path_to_save,plot=object_to_save,...)
  }else{
    saving_function(object_to_save,path_to_save,...)
  }
  # the double arrow <<- ensures that the variable (path_tracking_vector) in the parent env gets overridden 
  assign("path_tracking_vector",unique(c(parent.frame()$path_tracking_vector,path_to_save)),envir = parent.frame())
}

save_track_plot <- function(object_to_save, 
                            output_extension="pdf", 
                            output_path="data/07_output/03_figures/",
                            saving_function=ggsave,
                            width=NA,
                            height=NA,
                            units="cm",
                            ...){
  
  if(any(class(object_to_save)%in%c("name"))){
    object_name <- deparse(object_to_save)  
    object_to_save <- eval(object_to_save,envir = parent.frame())
  }else{
    object_name <- deparse(substitute(object_to_save))
  }
  path_to_save <- paste0(output_path,object_name,".",output_extension)
  
  if(deparse(substitute(saving_function))=="ggsave"){
    # print("In GGsave")
    # print(saving_function)
    # print(path_to_save)
    saving_function(filename=path_to_save,plot=object_to_save,width=width,height=height,units=units,...)
  }else{
    saving_function(object_to_save,path_to_save,...)
  }
  # the double arrow <<- ensures that the variable (path_tracking_vector) in the parent env gets overridden 
  assign("path_tracking_vector",unique(c(parent.frame()$path_tracking_vector,path_to_save)),envir = parent.frame())
}
