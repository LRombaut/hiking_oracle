rm(list=ls())
library(lubridate)
library(ggplot2)

#extract starting time as numeric in minutes/ date in Date format/ time in days since last hike as predictor
hikes <- read.csv("hikes_data.csv")
datetime <- paste(hikes$date, hikes$start_time, sep=" ")
hikes$datetime <- as_datetime(datetime, format="%d/%m/%Y %H:%M")
hikes$start_time <- hour(hikes$datetime)*60 + minute(hikes$datetime)
hikes$date <- as.Date(hikes$datetime)
hikes <- hikes[order(hikes$date),] # put hikes in order of date
hikes$date_last_hike <- numeric(155)
for(i in 1:length(hikes$date)){
  t <- hikes$date[i] - hikes$date[i-1]
  hikes$date_last_hike[i] <- as.numeric(t[1])
}  
hikes$date_last_hike[1] <- 0
hikes$date_last_hike <- hikes$date_last_hike/7 - 1 #units of weeks since last hike iso days centred on 1 week
hikes$date_since <- as.numeric(hikes$date - hikes$date[1]) #days since start of the hiking group
hikes$date_since <- hikes$date_since/max(hikes$date_since)
hikes$month <- month(hikes$date)
hikes$year <- year(hikes$date)
hikes$is_2022 <- as.integer(hikes$year == 2022)

#winter effect
is_winter <- numeric(155L)
for(i in 1:length(is_winter)){
  is_winter[i] <- switch(hikes$month[i], 1,1,0,0,0,0,0,0,0,0,1,1 ) #2 seasons starting november, december, january, february,..
}
hikes$is_winter <- is_winter

#remove hikes that have a signup cap
sum(!is.na(hikes$cap))
hikes <- hikes[which(is.na(hikes$cap)),]

#add rainfall data
rain_level <- numeric(124L)
for(i in 1:length(rain_level)) rain_level[i] <- ifelse(hikes$hourly_precipitation_peak_mm[i] > 0, 1, 0) #binary indicator var for rain
hikes$rain_level <- rain_level

#Sunday effect
dow <- weekdays(hikes$date)
table(dow)

for(i in 1:length(dow)){
  dow[i] <- ifelse(dow[i] == "Sunday", 1, 0)
}
table(dow)
hikes$dow <- as.integer(dow)

#early start time effect
morning_start <- hikes$start_time <= 960 & hikes$start_time >= 500
sum(morning_start)
dt <- hikes[morning_start,]  
hist(dt$start_time, breaks=10)
MST <- mean(dt$start_time)
SDST <- sd(dt$start_time)
hikes$start_time_std <- (hikes$start_time - MST)/SDST
hikes$morning_start <- as.integer(morning_start)


saveRDS(hikes, file="hikes.RDS")




