rm(list=ls())
library(lubridate)

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
hikes$month <- month(hikes$date)

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

#examine data distributions and summary statistics
par(mfrow=c(1,5))
hist(hikes$signups[hikes$special_category == "regular"])
hist(hikes$signups[hikes$special_category == "heavy_hike"])
hist(hikes$signups[hikes$special_category == "city_trip"])
hist(hikes$signups[hikes$special_category == "other_special"])
hist(hikes$signups[hikes$special_category == "special_nature"])
hist(hikes$signups[hikes$special_category == "night_hike"])
hist(hikes$signups[hikes$special_category == "game"])


aggregate(signups ~ special_category, data=hikes, mean)
aggregate(signups ~ special_category, data=hikes, var)
table(hikes$special_category)


hist(hikes$date_last_hike)
hist(hikes$start_time)
hist(hikes$distance_km)
hist(hikes$hourly_precipitation_peak_mm)
hist(hikes$Min.temp)
hist(hikes$Max.temp)

saveRDS(hikes, file="hikes.RDS")




