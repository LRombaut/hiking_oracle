rm(list=ls())
library(dplyr)
library(rethinking)
library(ggplot2)
library(tsibble)
library(lubridate)
library(timetk)
set.seed(289)

dat <- readRDS("hikes.RDS")
rownames(dat) <- seq(1,length(dat$date))
dat$year <- year(dat$date) - 2021

tbl <- tibble(
  date= dat$date,
  signups= dat$signups,
  key= dat$hike_id
)
ts <- as_tsibble(tbl, index=date, key=key, regular=FALSE)

ggplot(data= ts, aes(x= date, y= signups))+
  geom_point(col=rangi2, pch=1)+
  geom_smooth()+
  scale_y_continuous(breaks=c(0,10,20,30,50,75,100), limits=c(0,100))+
  labs(x='Date', y='Signups')+
  theme_bw()


plot_seasonal_diagnostics(ts, .date_var = date, .value = signups, .feature_set = "year")
#august, september and december are lean months/ april stands out because it has the hyacinths and blossom hikes
plot_seasonal_diagnostics(ts, .date_var = date, .value = signups, .feature_set = "month.lbl")
#hikes on sunday seem to have more signups than those on saturday/ on other days of the week fewer hikes have been organised but when they happen lots of people show up (probs a holiday effect)
plot_seasonal_diagnostics(ts, .date_var = date, .value = signups, .feature_set = "wday.lbl")


acf(ts$signups, lag.max=20) #slight correlation between successive hike turnouts

'''Model 4.0 2022 effect'''

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  year= dat$is_2022
)

m4.0 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + y*year + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    y ~ dnorm(0, 0.5), #year effect
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

precis(m4.0, depth=2)

m4.0.prior <- extract.prior(m4.0)
m4.0.post <- extract.samples(m4.0)

dens(m4.0.post$y)
dens(m4.0.prior$y, col='red', add=TRUE)

'''Model 4.1 linear trend'''

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  year= scale(dat$date_since)
)

hist(d$year)
plot(d$year, d$signups)

m4.1 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + y*year + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    y ~ dnorm(0, 0.3), #year effect
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

precis(m4.1, depth=2)

m4.1.prior <- extract.prior(m4.1)
m4.1.post <- extract.samples(m4.1)

dens(m4.1.post$y)
dens(m4.1.prior$y, col='red', add=TRUE)

'''Model 4.2 individual year effect'''

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  yearid= dat$year
)

m4.2 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + y[yearid] + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    y[yearid] ~ dnorm(0, 0.3), #year effect
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

precis(m4.2, depth=2)

compare(m4.0, m4.1, m4.2)

'''Model 4.0.1 - 4 Seasons of 3 months each'''

month <- as.integer(dat$month)
months3 <- integer(length=124L)
for(i in 1:length(month)){
  months3[i] <- switch(month[i], 1,1,2,2,2,3,3,3,4,4,4,1 ) #4 seasons starting december, january, february...
}
hist(months3, breaks=50)
dat$months3 <- months3

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  monthid= dat$months3,
  year= dat$is_2022
)

#model specification
m4.0.1 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + b[monthid] + y*year + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    b[monthid] ~ dnorm(0, 0.2), #season adds to the effect of hike type
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    y ~ dnorm(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

#chain diagnostics
precis(m4.0.1, depth=2)

'''Model 4.0.2 - Winter Season Effect'''

month <- as.integer(dat$month)
months6 <- integer(length=124L)
for(i in 1:length(month)){
  months6[i] <- switch(month[i], 1,1,0,0,0,0,0,0,0,0,1,1 ) #2 seasons starting november, december, january, february,..
}
hist(months6, breaks=50)
dat$months6 <- months6

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  is_winter= dat$months6,
  year= dat$is_2022
)

#model specification
m4.0.2 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + w*is_winter + y*year + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    w ~ dnorm(0, 0.3), #season adds to the effect of hike type
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    y ~ dnorm(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

#chain diagnostics
precis(m4.0.2, depth=2)
a_params <- paste0('a[',as.character(1:7),']')
traceplot(m4.0.2, pars=c(a_params,'a_bar', 'sigma_a', 'phi', 'r', 'y', 'w'), window=c(200,1000))
trankplot(m4.0.2, pars=c(a_params,'a_bar', 'sigma_a', 'phi', 'r', 'y', 'w'), window=c(200,1000))

psis <- PSIS(m4.0.2, pointwise=TRUE) 
sum(psis$k > 0.5)

'''Model 4.0.3 2 seasons summer and winter'''

month <- as.integer(dat$month)
months6 <- integer(length=124L)
for(i in 1:length(month)){
  months6[i] <- switch(month[i], 1,1,0,0,0,1,1,1,0,0,0,1 ) #2 seasons starting november, december, january, february,..
}
hist(months6, breaks=50)
dat$months6 <- months6

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  is_suwinter= dat$months6,
  year= dat$is_2022
)

#model specification
m4.0.3 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + sw*is_suwinter + y*year + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    sw ~ dnorm(0, 0.3), #season adds to the effect of hike type
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    y ~ dnorm(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

precis(m4.0.3, depth=2)
precis(m4.0.2, depth=2)
precis(m4.0.1, depth=2)

compare(m4.0.1, m4.0.2, m4.0.3)



'''Sunday Effect '''

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  is_winter= dat$is_winter,
  year= dat$is_2022,
  is_sunday= dat$dow
)

#model specification
m4.0.2.s <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + w*is_winter + y*year + r*rain + dow*is_sunday, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    w ~ dnorm(0, 0.3), #season adds to the effect of hike type
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    y ~ dnorm(0, 0.5),
    dow ~ dnorm(0, 0.3),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

#chain diagnostics
precis(m4.0.2.s, depth=2)
a_params <- paste0('a[',as.character(1:7),']')
traceplot(m4.0.2.s, pars=c(a_params,'a_bar', 'sigma_a', 'phi', 'r', 'y', 'w', 'dow'), window=c(200,1000))
trankplot(m4.0.2.s, pars=c(a_params,'a_bar', 'sigma_a', 'phi', 'r', 'y', 'w', 'dow'), window=c(200,1000))

psis <- PSIS(m4.0.2, pointwise=TRUE) 
sum(psis$k > 0.5)

compare(m4.0.2.s, m4.0.2)

prior <- extract.prior(m4.0.2.s)
post <- extract.samples(m4.0.2.s)

dens(post$dow)
dens(prior$dow, col='red', add=TRUE)

mu <- link(m4.0.2.s)
mu_mean <- apply(mu, 2, mean)

plot( log(dat$signups) ~ log(mu_mean) , col=rangi2, xlim=c(1,4.5), ylim=c(1,4.5),
      xlab='predicted signups', ylab='observed signups')
abline(a=0, b=1, lty=2)





