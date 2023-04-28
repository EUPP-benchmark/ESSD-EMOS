rm(list = ls())
library(zoo)
library(crch)
library(ncdf4)

path <- '/path/to/data/'

### Loading test forecasts
fc_test <- nc_open(paste0(path, 'data/ESSD_benchmark_test_data_forecasts.nc'))
station_id_fc_test <- ncvar_get(fc_test, varid = "station_id")
fctime_fc_test<- as.POSIXct(ncvar_get(fc_test, varid = "time"), origin = '1970-01-01')
data_fc_test <- ncvar_get(fc_test, varid = "t2m")
lt_fc_test<- ncvar_get(fc_test, varid = "step")
ens_fc_test<- ncvar_get(fc_test, varid = "number")
nc_close(fc_test)

### Loading test observations
obs_test <- nc_open(paste0(path, 'data/ESSD_benchmark_test_data_observations.nc'))
station_id_obs_test <- ncvar_get(obs_test, varid = "station_id")
fctime_obs_test<- as.POSIXct(ncvar_get(obs_test, varid = "time"), origin = '1970-01-01')
data_obs_test <- ncvar_get(obs_test, varid = "t2m")
lt_obs_test<- ncvar_get(obs_test, varid = "step")
nc_close(obs_test)

### Loading trainig forecasts
fc_trai <- nc_open(paste0(path, 'data/ESSD_benchmark_training_data_forecasts.nc'))
station_id_fc_trai <- ncvar_get(fc_trai, varid = "station_id")
year_fc_trai <- ncvar_get(fc_trai, varid = "year")
time_fc_trai <- ncvar_get(fc_trai, varid = "time")
data_fc_trai <- ncvar_get(fc_trai, varid = "t2m")
lt_fc_trai<- ncvar_get(fc_trai, varid = "step")
ens_fc_trai<- ncvar_get(fc_trai, varid = "number")
nc_close(fc_trai)

### Loading trainig observations
obs_trai <- nc_open(paste0(path, 'data/ESSD_benchmark_training_data_observations.nc'))
station_id_obs_trai <- ncvar_get(obs_trai, varid = "station_id")
year_obs_trai <- ncvar_get(obs_trai, varid = "year")
time_obs_trai <- ncvar_get(obs_trai, varid = "time")
data_obs_trai <- ncvar_get(obs_trai, varid = "t2m")
lt_obs_trai<- ncvar_get(obs_trai, varid = "step")
nc_close(obs_trai)


### Loop over stations
for(st in station_id_fc_test){
  print(paste0('Forecast at Station: ', st, ' (', which(station_id_fc_test == st), ' from ', length(station_id_fc_test), ')'))
  save.file <-  paste0(path, 'fc/fc.', st,'.rda')
  
  test.all <- NULL
  
  ### Loop over lead times
  for(lt in lt_fc_test){
    cat('\r', paste0('Forecast at Lead Time: ', lt))
    
    ### Building test data for station and lead time
    obs <- data_obs_test[which(lt_obs_test == lt), , which(station_id_obs_test == st)]
    time <- fctime_obs_test + lt * 3600
    obs <- cbind(fctime_obs_test, lt, st, obs)
    obs <- zoo(obs, time)
    colnames(obs) <- c('init', 'lt', 'stat', 'obs')
    
    fc <- data_fc_test[, which(lt_fc_test == lt), , which(station_id_fc_test == st)]
    ens.mu <- apply(fc, 2, mean)
    ens.sd <- apply(fc, 2, sd)
    test <- cbind(ens.mu, ens.sd)
    
    time <- fctime_fc_test + lt * 3600
    test <- zoo(test, time)
    test <- merge(obs, test)
    
    
    ### Building training data for station and lead time
    trai.all <- NULL
    for(year in year_fc_trai){
      
      obs <- data_obs_trai[which(lt_obs_trai == lt), which(year_obs_trai == year), , which(station_id_obs_trai == st)]
      year.dummy <- as.POSIXct(paste0(2017 - 20 + year,'-01-02'))
      time <- year.dummy + time_obs_trai * 3600 * 24 + lt * 3600
      fctime_obs_trai <- year.dummy + time_obs_trai * 3600 * 24
      obs <- cbind(fctime_obs_trai, lt, st, obs)
      obs <- zoo(obs, time)
      colnames(obs) <- c('init', 'lt', 'stat', 'obs')
      
      fc <- data_fc_trai[, which(lt_fc_trai == lt), which(year_obs_trai == year), , which(station_id_fc_trai == st)]
      ens.mu <- apply(fc, 2, mean)
      ens.sd <- apply(fc, 2, sd)
      trai <- cbind(ens.mu, ens.sd)
      time <- year.dummy + time_fc_trai * 3600 * 24 + lt * 3600
      
      trai <- zoo(trai, time)
      trai <- merge(obs, trai)
      
      trai.all <- rbind(trai.all, trai)
    }
    
    trai <- na.omit(trai.all)
    ### Using only data for trainig before 2017-01-01
    trai <- trai[which(index(trai) < as.POSIXct('2017-01-01')),]
    
    ### One Station has a few lead times with no data, therefore this if()
    if(nrow(trai) >= 30){
      trai$obs <- trai$obs - 273.15
      test$obs <- test$obs - 273.15
      trai$ens.mu <- trai$ens.mu - 273.15
      test$ens.mu <- test$ens.mu - 273.15
      
      ### Adding sine and cosine for day of the year to capture seasonality    
      yday <- as.POSIXlt(index(trai))$yday
      trai$sin.y1 <- sin(2 * pi * yday / 365)
      trai$cos.y1 <- cos(2 * pi * yday / 365)
      trai$sin.y2 <- sin(4 * pi * yday / 365)
      trai$cos.y2 <- cos(4 * pi * yday / 365)
      
      ### Fitting EMOS
      fit <- crch(obs ~ ens.mu + sin.y1 + cos.y1 + sin.y2 + cos.y2 | 
                    log(ens.sd) + sin.y1 + cos.y1 + sin.y2 + cos.y2, data = trai)
      
      ### Predicting 
      test <- na.omit(test)
      yday <- as.POSIXlt(index(test))$yday
      test$sin.y1 <- sin(2 * pi * yday / 365)
      test$cos.y1 <- cos(2 * pi * yday / 365)
      test$sin.y2 <- sin(4 * pi * yday / 365)
      test$cos.y2 <- cos(4 * pi * yday / 365)
      
      test$fc <- predict(fit, newdata = test)
      test$sd <- predict(fit, newdata = test, type = 'scale')
      
      
      test.all <- rbind(test.all, data.frame(test))
    }  
    
    test <- test.all
    print(mean(abs(test$obs - test$fc)))
    
    save(test, file = save.file, version = 2)
  }
}  