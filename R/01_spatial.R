
get_ac_shapes <- function(ac_shapefile_paths){
  # tar_load(ac_shapefile_paths)
  # DataMeet assembly constituencies (2008 delimitation); state names normalised like ac_delim
  ac_shapes <- st_read(str_subset(ac_shapefile_paths,"\\.shp$"),quiet=TRUE) %>%
    st_make_valid() %>%
    mutate(state=str_remove_all(str_to_lower(ST_NAME),"[^a-z]"),
           state=case_match(state,
                            "orissa"~"odisha",
                            "uttarkhand"~"uttarakhand",
                            .default=state)) %>%
    select(state,AC_NO,AC_NAME)
  return(ac_shapes)
}

get_district_centroids <- function(ac_shapes, ac_delim){
  # tar_load(ac_shapes)
  # tar_load(ac_delim)
  # AC numbers and names in the shapefile agree with TCPD Delim4 in every state (97-100% of
  # names), so ACs are matched by number and dissolved into TCPD districts
  district_polygons <- ac_shapes %>%
    inner_join(ac_delim %>% select(state,AC_No,district),by=c("state","AC_NO"="AC_No")) %>%
    group_by(state,district) %>%
    summarise(n_ac=n(),.groups="drop")
  centroid_xy <- st_coordinates(st_centroid(st_geometry(district_polygons)))
  district_centroids <- district_polygons %>%
    st_drop_geometry() %>%
    mutate(lon=centroid_xy[,1],
           lat=centroid_xy[,2])
  return(district_centroids)
}

# Great-circle distances (km) between two sets of points; rows = first set
haversine_km <- function(lon1, lat1, lon2, lat2){
  to_rad <- pi/180
  dlat <- outer(lat1,lat2,"-")*to_rad
  dlon <- outer(lon1,lon2,"-")*to_rad
  a <- sin(dlat/2)^2 + outer(cos(lat1*to_rad),cos(lat2*to_rad))*sin(dlon/2)^2
  a[a>1] <- 1
  return(2*6371.0088*asin(sqrt(a)))
}

# Goyal (1981) districts located at the centroid of the TCPD district carrying their name
locate_goyal_districts <- function(riots_goyal_clean, district_centroids){
  goyal_locations <- riots_goyal_clean %>%
    zap_labels() %>%
    distinct(dist,state,district,state_goyal) %>%
    left_join(district_centroids,by=c("state","district"))
  stopifnot(!anyDuplicated(goyal_locations$dist),!anyNA(goyal_locations$lon))
  return(goyal_locations)
}

get_district_parents <- function(riots_goyal_clean, district_centroids){
  # tar_load(riots_goyal_clean)
  # tar_load(district_centroids)
  # Every TCPD district in the 16 riot-data states gets a parent Goyal district: itself when
  # the names match, otherwise the nearest Goyal district in the same state. The parent
  # supplies controls and the (state) festival list, never riots. Independent of the RNI data,
  # so both RNI versions share it.
  goyal_locations <- locate_goyal_districts(riots_goyal_clean,district_centroids)
  receivers <- district_centroids %>%
    filter(state%in%goyal_locations$state) %>%
    select(state,district,lon,lat)
  distance_km <- haversine_km(receivers$lon,receivers$lat,goyal_locations$lon,goyal_locations$lat)
  distance_km[outer(receivers$state,goyal_locations$state,"!=")] <- Inf
  nearest <- apply(distance_km,1,which.min)
  district_parents <- receivers %>%
    mutate(dist=goyal_locations$dist[nearest],
           state_goyal=goyal_locations$state_goyal[nearest],
           parent_km=distance_km[cbind(seq_along(nearest),nearest)],
           matched=(parent_km==0),
           district_id=paste(state,district,sep="_"))
  stopifnot(all(district_parents$matched==(paste(district_parents$state,district_parents$district)%in%
                                             paste(goyal_locations$state,goyal_locations$district))))
  return(district_parents)
}

get_riot_kernel <- function(district_parents, riots_goyal_clean, festival_iyer, district_centroids){
  # tar_load(district_parents)
  # tar_load(riots_goyal_clean)
  # tar_load(festival_iyer)
  # tar_load(district_centroids)
  # Iyer & Shrivastava's spatial kernel, checked against dataset_robustness.dta:
  #   riotnear_h     = exp(-d^2/(2h^2)), d = km to the nearest district with a riot that year
  #                    (0 if the district had one itself)
  #   riotall200     = sum_j nriot_j * exp(-d_ij^2/(2*200^2)) over the 339 Goyal districts
  #   fesnormdist200 = sum_j fes_j   * exp(-d_ij^2/(2*200^2))
  goyal_locations <- locate_goyal_districts(riots_goyal_clean,district_centroids)
  distance_km <- haversine_km(district_parents$lon,district_parents$lat,goyal_locations$lon,goyal_locations$lat)
  kernel_200 <- exp(-distance_km^2/(2*200^2))

  source_years <- riots_goyal_clean %>%
    zap_labels() %>%
    select(dist,year,state_goyal,riot,nriot,fridayfestival) %>%
    left_join(festival_iyer,by=c("state_goyal","year"))

  years <- sort(unique(source_years$year))
  riot_kernel_list <- vector(mode='list',length=length(years))
  for(i in seq_along(years)){
    sources <- source_years %>% filter(year==years[i])
    sources <- sources[match(goyal_locations$dist,sources$dist),]
    is_riot <- sources$riot==1
    riot_dist_km <- if(any(is_riot)) apply(distance_km[,is_riot,drop=FALSE],1,min) else rep(Inf,nrow(distance_km))
    riot_kernel_list[[i]] <- tibble(state=district_parents$state,
                                    district=district_parents$district,
                                    year=years[i],
                                    riot_dist_km=riot_dist_km,
                                    riotall200=as.vector(kernel_200%*%sources$nriot),
                                    fesnormdist200=as.vector(kernel_200%*%sources$fes_iyer),
                                    ffnormdist200=as.vector(kernel_200%*%sources$fridayfestival))
  }
  riot_kernel <- bind_rows(riot_kernel_list)
  for(h in c(100,150,200,250,300)){
    riot_kernel[[paste0("riotnear",h)]] <- exp(-riot_kernel$riot_dist_km^2/(2*h^2))
  }
  return(riot_kernel)
}

get_kernel_validation <- function(riots_goyal_clean, district_centroids, iyer_robustness_raw, festival_iyer){
  # tar_load(riots_goyal_clean)
  # tar_load(district_centroids)
  # tar_load(iyer_robustness_raw)
  # tar_load(festival_iyer)
  # Rebuild Iyer's kernel for Iyer's own districts and years and compare with their file
  path_tracking_vector <- c()
  output_path <- "data/02_output/08_kernel_validation/"
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)

  goyal_locations <- locate_goyal_districts(riots_goyal_clean,district_centroids)
  distance_km <- haversine_km(goyal_locations$lon,goyal_locations$lat,goyal_locations$lon,goyal_locations$lat)
  riots <- riots_goyal_clean %>% zap_labels() %>% select(dist,year,state_goyal,riot,fes)

  iyer <- iyer_robustness_raw %>%
    zap_labels() %>%
    select(dist,year,riotneardist_iyer=riotneardist,riotnear200_iyer=riotnear200) %>%
    filter(!is.na(riotneardist_iyer))
  comparison_list <- vector(mode='list',length=0)
  for(yy in sort(unique(iyer$year))){
    sources <- riots %>% filter(year==yy)
    is_riot <- sources$riot[match(goyal_locations$dist,sources$dist)]==1
    comparison_list[[length(comparison_list)+1]] <- tibble(dist=goyal_locations$dist,
                                                           year=yy,
                                                           riotneardist=apply(distance_km[,is_riot,drop=FALSE],1,min))
  }
  kernel_comparison <- bind_rows(comparison_list) %>%
    inner_join(iyer,by=c("dist","year")) %>%
    mutate(riotnear200=exp(-riotneardist^2/(2*200^2)),
           abs_error_km=abs(riotneardist-riotneardist_iyer))

  festival_comparison <- riots %>%
    filter(!is.na(fes)) %>%
    left_join(festival_iyer,by=c("state_goyal","year"))

  kernel_validation <- tibble(
    district_years=nrow(kernel_comparison),
    years=paste(range(kernel_comparison$year),collapse="-"),
    corr_distance=cor(kernel_comparison$riotneardist,kernel_comparison$riotneardist_iyer),
    corr_riotnear200=cor(kernel_comparison$riotnear200,kernel_comparison$riotnear200_iyer),
    median_abs_error_km=median(kernel_comparison$abs_error_km),
    p90_abs_error_km=quantile(kernel_comparison$abs_error_km,0.90),
    p95_abs_error_km=quantile(kernel_comparison$abs_error_km,0.95),
    mean_abs_diff_riotnear200=mean(abs(kernel_comparison$riotnear200-kernel_comparison$riotnear200_iyer)),
    share_riotnear200_within_0.05=mean(abs(kernel_comparison$riotnear200-kernel_comparison$riotnear200_iyer)<0.05),
    fes_iyer_equals_iyer_fes=mean(festival_comparison$fes_iyer==festival_comparison$fes),
    fes_years=paste(range(festival_comparison$year),collapse="-"))
  save_track_object(kernel_validation,write.csv,output_extension="csv",output_path=output_path,row.names=FALSE)

  kernel_validation_plot <- ggplot(kernel_comparison,aes(x=riotnear200_iyer,y=riotnear200))+
    geom_point(alpha=0.15,size=0.6)+
    geom_abline(slope=1,intercept=0,colour="#E66100")+
    coord_equal()+
    theme_bw(base_size=11)+
    labs(x="riotnear200, Iyer & Shrivastava (2018)",
         y="riotnear200, rebuilt from AC-map centroids",
         title="Spatial riot kernel: rebuilt vs. original",
         subtitle=sprintf("%s district-years, %s; correlation %.3f",
                          format(nrow(kernel_comparison),big.mark=","),kernel_validation$years,kernel_validation$corr_riotnear200))
  save_track_plot(kernel_validation_plot,output_path=output_path,height=1500,width=1500,units='px')

  return(path_tracking_vector)
}
