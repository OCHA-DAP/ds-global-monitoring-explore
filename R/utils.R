
#' st_read_zip
#'
#' @param path 
#' @param layer \code{character} name of layer. If NULL (default) first layer in zip will be read.
#'
#' @return
#' @export
#'
#' @examples \dontrun{
#' library(sf)
#' library(tidyverse)
#' 
#' fp <-  file.path (...)
#' st_zip_read(path = fp)
#' }
st_read_zip <-  function(path,layer=NULL){
  df_layers <- st_layers_zip(path=path)
  if(is.null(layer)){
    cat("No layer specified - reading first layer in zip")
    temp <- tempfile()
    unzip(zipfile = path, exdir = temp)
    st_read(dsn = temp,layer = df_layers$name[1])
  }
}


#' st_layers_zip
#'
#' @param path \code{character} file path
#' @param unlink \code{logical} 
#'
#' @return
#' @export
#'
#' @examples \dontrun{
#' library(sf)
#' fp <- file.path(...)
#' st_layers_zip(fp) 
#'
#' }
st_layers_zip <- function(path,unlink=T){
  temp <- tempfile()
  unzip(zipfile = path, exdir = temp)
  return(st_layers(temp))
  if(unlink){
    unlink(temp)  
  }
  
}



  
