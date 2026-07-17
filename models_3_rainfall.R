rm(list=ls())
library(rethinking)
set.seed(261)

dat <- readRDS("hikes.RDS")
rownames(dat) <- seq(1,length(dat$date))

'''Data Exploration/Visualisation'''

hist(dat$hourly_precipitation_peak_mm, breaks=50)
plot(dat$hourly_precipitation_peak_mm, dat$signups)
plot(dat$hourly_precipitation_peak_mm, dat$signups, xlim=c(0,3))
cor.test(dat$hourly_precipitation_peak_mm, dat$signups) #no overall correlation

dat.reg <- dat[dat$special_category == 'regular',]
cor.test(dat.reg$hourly_precipitation_peak_mm, dat.reg$signups) #no correlation within regular hikes either

rain_level <- numeric(124L)

for(i in 1:length(rain_level)){
  if(dat$hourly_precipitation_peak_mm[i] == 0){
    rain_level[i] <- 1L
  }else if(dat$hourly_precipitation_peak_mm[i] <= 0.5){
    rain_level[i] <- 2L
  }else rain_level[i] <- 3L
}

hist(rain_level)
dat$rain_level <- rain_level

plot(rain_level, dat$signups)

cor.test(dat$signups, rain_level)
idx <- which(dat$special_category == 'regular')
cor.test(dat$signups[idx], rain_level[idx]) #still no evidence of a correlation

tmp <- with(dat, by(dat, special_category, function(x) lm(signups ~ rain_level, data=x)))
summary(tmp$city_trip)
summary(tmp$game)
summary(tmp$heavy_hike)
summary(tmp$night_hike)
summary(tmp$other_special)
summary(tmp$regular)
summary(tmp$special_nature) 
# the estimated slopes are negative but non-significant

tmp <- with(dat, aggregate(signups, by=list(special_category, rain_level), mean))

#I will try two levels of rain now - no rain vs. some rain

rain_level <- numeric(124L)
for(i in 1:length(rain_level)) rain_level[i] <- ifelse(dat$hourly_precipitation_peak_mm[i] > 0, 1, 0)
sum(rain_level)
dat$rain_level <- rain_level

tmp <- with(dat, aggregate(signups, by=list(special_category, rain_level), mean))
cor.test(dat$rain_level, dat$signups) #no overall negative correlation still

tmp <- with(dat, by(dat, special_category, function(x) lm(signups ~ rain_level, data=x)))
summary(tmp$city_trip)
summary(tmp$game)
summary(tmp$heavy_hike)
summary(tmp$night_hike)
summary(tmp$other_special)
summary(tmp$regular)
summary(tmp$special_nature) 

modlm1 <- lm(signups ~ 0 + special_category + rain_level, data=dat) #p=0.065 for rain_level
summary(modlm1)
modlm3.1 <- lm(signups ~ 0 + special_category + rain_level + rain_level*special_category, data=dat) 
summary(modlm3.1)

'''Model With 2 levels of Rain'''

rain_level <- integer(124L)
for(i in 1:length(rain_level)) rain_level[i] <- ifelse(dat$hourly_precipitation_peak_mm[i] > 0, 1, 0)

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= rain_level
)

m3.1 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + r*rain,
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.25),
    sigma ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

#chain diagnostics and posterior summary
traceplot(m3.1, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r'), window=c(200,1000))
trankplot(m3.1, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r'), window=c(200,1000))

precis(m3.1, depth=2)
levels(as.factor(dat$special_category)) 
psis <- PSIS(m3.1, pointwise=TRUE) # no Pareto k values greater than 0.5 

sum(psis$k > 0.5)

#prior-posterior comparison

m3.1.prior <- extract.prior(m3.1)
m3.1.post <- extract.samples(m3.1)
dens(m3.1.post$r)
dens(m3.1.prior$r, col='red', add=TRUE) #clear evidence of a negative effect of rain mean=-0.17 89%CI= -0.33 to 0.00


'''Model With 3 levels of Rain'''

#create indicator variables for light and heavy rain
light_rain <- integer(124L)
heavy_rain <- integer(124L)
for(i in 1:length(dat$hourly_precipitation_peak_mm)){
  if(dat$hourly_precipitation_peak_mm[i] == 0){
    light_rain[i] <- 0L
    heavy_rain[i] <- 0L
  } else if(dat$hourly_precipitation_peak_mm[i] <= 0.5){
    light_rain[i] <- 1L
    heavy_rain[i] <- 0L
  } else{
    heavy_rain[i] <- 1L
    light_rain[i] <- 0L
  } 
} 

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  lrain= light_rain,
  hrain= heavy_rain
)

m3.2 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + lr*lrain + hr*hrain,
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.25),
    sigma ~ half_normal(0, 0.5),
    c(lr, hr) ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

#chain diagnostics and posterior summary
traceplot(m3.2, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'lr', 'hr'), window=c(200,1000))
trankplot(m3.2, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'lr', 'hr'), window=c(200,1000))

precis(m3.2, depth=2)
levels(as.factor(dat$special_category)) 

compare(m3.1, m3.2) #more complex model not better than the simple one with two rain levels

'''Model Treating Rain as a Continuous predictor'''

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$hourly_precipitation_peak_mm
)

m3.3 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + r*rain,
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.25),
    sigma ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with 1mm rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)


#chain diagnostics and posterior summary
traceplot(m3.3, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r'), window=c(200,1000))
trankplot(m3.3, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r'), window=c(200,1000))

precis(m3.3, depth=2)

compare(m3.1, m3.2, m3.3)

stancode(m3.1)
stancode(m3.2)
stancode(m3.3)








