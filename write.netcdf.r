rm(list = ls())
library(zoo)
library(ncdf4)


path <- '/path/to/'

### Copy original FC file to store forecasts in 
fc_test_org <- paste0(path, 'data/ESSD_benchmark_test_data_forecasts.nc')
fc_test_name <- paste0(path, 'data/1_ESSD-benchmark_ZAMG_EMOS-vX.X.nc')
system(paste('cp ', fc_test_org, ' ', fc_test_name))

fc_test <- nc_open(fc_test_name)
station_id_fc_test <- ncvar_get(fc_test, varid = "station_id")
fctime_fc_test<- as.POSIXct(ncvar_get(fc_test, varid = "time"), origin = '1970-01-01')
data_fc_test <- ncvar_get(fc_test, varid = "t2m")
lt_fc_test<- ncvar_get(fc_test, varid = "step")
ens_fc_test<- ncvar_get(fc_test, varid = "number")
nc_close(fc_test)

### Loop over stations
for(st in station_id_fc_test){
  cat('\r', paste0('Convert station: ', st, ' (',which(station_id_fc_test == st), ' of ', length(station_id_fc_test), ')'))
  
  ### Loop over lead times
  for(lt in lt_fc_test){
    file <-  paste0(path, 'fc/fc.', st,'.rda')
    
    if(file.exists(file)){
      ### Loading forecasts from the R format
      load(file)
      test <- test[which(test$lt == lt),]
      time <- rownames(test)
      test.mu <- test$fc + 273.15
      test.mu <- zoo(test.mu, as.POSIXct(time))
      sec <- as.POSIXlt(index(test.mu))$sec
      index(test.mu) <- index(test.mu) - sec
      
      test.sd <- test$sd
      test.sd <- zoo(test.sd, as.POSIXct(time))
      sec <- as.POSIXlt(index(test.sd))$sec
      index(test.sd) <- index(test.sd) - sec
      
      
      ### Draw 51 quantiles from the Gaussian distribution to match the  ECMWF members
      ### quantiles are evenly distributed between 1 and 99 percent (could be optimized, now slightly underdispersive)
      fc <- NULL
      for(q in seq(0.01, 0.99, length.out = 51)){
        quant <- qnorm(q, mean = test.mu, sd = test.sd)
        
        if(is.null(fc)){
          fc <- as.numeric(quant)
        }else{
          fc <- cbind(fc, as.numeric(quant))
        }
      }
      
      ### If now forecasts, fille up with NAs
      if(nrow(fc) == 0){
        fc <- data_fc_test[,which(lt_fc_test == lt), ,which(station_id_fc_test == st)]
        fc[1:length(fc)] <- NA
        fc <- t(fc)
        fc<- zoo(fc, fctime_fc_test + lt * 3600)
        fc <- data.frame(fc)
      }
      
      if(nrow(fc) != 730){
        fc <- zoo(fc, index(test.mu))
        colnames(fc) <- NULL
        dummy <- data_fc_test[,which(lt_fc_test == lt), ,which(station_id_fc_test == st)]
        dummy[1:length(dummy)] <- NA
        dummy <- t(dummy)
        dummy <- zoo(dummy, fctime_fc_test + lt * 3600)
        ind <- which(index(dummy) %in% index(dummy)[-which(index(dummy) %in% index(test.mu))])
        fc <- rbind(fc, dummy[ind,])
        fc <- data.frame(fc)
      }
      fc <- t(fc)
      data_fc_test[,which(lt_fc_test == lt), ,which(station_id_fc_test == st)] <- fc
    }else{
      data_fc_test[,which(lt_fc_test == lt), ,which(station_id_fc_test == st)] <- NA
    }
  }
}

### Write forecasts to netCDF file
nc <-  ncdf4::nc_open(fc_test_name, write = TRUE)
ncdf4::ncvar_put(nc, 't2m', data_fc_test)
nc_close(nc)


