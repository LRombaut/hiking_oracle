rm(list=ls())
library(rethinking)
library(ggplot2)
library(lubridate)
set.seed(32)

dat <- readRDS("hikes.RDS")
rownames(dat) <- seq(1,length(dat$date))

cor.test(dat$date_last_hike, dat$signups) #r=0.139 slight positive correlation

hist(dat$date_last_hike)
plot(dat$date_last_hike, dat$signups)
ggplot(data=dat, aes(x=date_last_hike, y=signups))+
  geom_point()+
  geom_smooth(method='lm')

modlm <- lm(signups ~ date_last_hike, data=dat)
summary(modlm)
plot(modlm)
#try nonlinear association
dat$lh2 <- dat$date_last_hike^2
modlm5 <- lm(signups ~ date_last_hike + lh2, data=dat)
summary(modlm5) #not promising
plot(modlm5)


'''Model 5 Effect for weeks since last hike'''

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  is_winter= dat$is_winter,
  is_2022= dat$is_2022,
  last_hike= dat$date_last_hike,
  is_sunday= dat$dow
)

m5 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + r*rain + y*is_2022 + w*is_winter + dow*is_sunday + wlh*last_hike,
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.25),
    sigma ~ half_normal(0, 0.5),
    y ~ dnorm(0, 0.5),
    dow ~ dnorm(0, 0.3),
    w ~ dnorm(0, 0.3),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    wlh ~ dnorm(0, 0.3),
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

precis(m5, depth=2)
#chain diagnostics and posterior summary
traceplot(m5, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r', 'wlh', 'y', 'w', 'dow'), window=c(200,1000))
trankplot(m5, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r', 'wlh', 'y', 'w', 'dow'), window=c(200,1000))

#prior-posterior comparison

m5.prior <- extract.prior(m5)
m5.post <- extract.samples(m5)
dens(m5.post$wlh, xlim=c(-0.2,0.2))
dens(m5.prior$wlh, col='red', add=TRUE) #some evidence of an effect of weeks since the last hike

compare(m5, m4.0.2.s) #the evidence is not really that strong that it has enough effect to be included in the model

#posterior predictive checks
m5.pred <- link(m5)
mu_pred <- apply(m5.pred, 2, mean)

plot( dat$signups ~ mu_pred , col=rangi2 , xlim=c(0,60),
      xlab='predicted signups', ylab='observed signups')
abline(a=0, b=1, lty=2)
cor(dat$signups, mu_pred)

#predicted effect of weeks since last hike
levels(as.factor(dat$special_category))
simdat <- list(
  last_hike= seq(-1,3,length.out=50),
  rain= rep(0,50), #no rain
  typeid= rep(6,50), #regular hikes
  is_sunday= rep(0,50),
  is_2022= rep(0,50),
  is_winter= rep(0,50)
)

sims <- sim(m5, data=simdat)
simpred <- link(m5, data=simdat)

mu_pred <- apply(simpred, 2, mean)
mu_PI <- apply(simpred, 2, PI)
pred_PI <- apply(sims, 2, PI)
wlh <- seq(-1,3,length.out=50)
reg.hikes <- dat[dat$special_category == 'regular',]

plot(NULL, xlim=c(-1,4), ylim=c(0,50), xlab='weeks since last hike', ylab='signups')
lines(wlh, mu_pred)
shade(mu_PI, wlh)
points(reg.hikes$date_last_hike, reg.hikes$signups)

simdat2 <- list(
  last_hike= seq(-1,3,length.out=50),
  rain= rep(1,50), #no rain
  typeid= rep(6,50), #regular hikes
  is_sunday= rep(0,50),
  is_2022= rep(0,50),
  is_winter= rep(0,50)
)

sims <- sim(m5, data=simdat2)
simpred <- link(m5, data=simdat2)

mu_pred <- apply(simpred, 2, mean)
mu_PI <- apply(simpred, 2, PI)
pred_PI <- apply(sims, 2, PI)

lines(wlh, mu_pred, col='blue')
shade(mu_PI, wlh, col=col.alpha('blue', alpha=0.2)) 

'''Model 6 effect of early start times on hike signups '''

morning_start <- dat$start_time <= 960 & dat$start_time >= 500
sum(morning_start)
dt <- dat[morning_start,]  
hist(dt$start_time, breaks=10)
MST <- mean(dt$start_time)
SDST <- sd(dt$start_time)
dat$start_time_std <- (dat$start_time - MST)/SDST
hist(dat$start_time_std)
hist(dat[morning_start,]$start_time_std)
plot(dat$start_time_std, dat$signups)

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  is_winter= dat$is_winter,
  is_2022= dat$is_2022,
  last_hike= dat$date_last_hike,
  is_sunday= dat$dow,
  morning_start= dat$morning_start,
  start_time= dat$start_time_std
)

m6 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + r*rain + y*is_2022 + w*is_winter + es*morning_start*start_time + dow*is_sunday + wlh*last_hike,
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.25),
    sigma ~ half_normal(0, 0.5),
    y ~ dnorm(0, 0.5),
    dow ~ dnorm(0, 0.3),
    w ~ dnorm(0, 0.3),
    es ~ dnorm(0, 0.3),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    wlh ~ dnorm(0, 0.3),
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

precis(m6, depth=2)

post <- extract.samples(m6)
prior <- extract.prior(m6)

dens(post$wlh)
dens(prior$wlh, col='red', add=TRUE)
dens(post$es)
dens(prior$es, col='red', add=TRUE)
dens(post$dow)
dens(prior$phi, col='red')
dens(post$phi, add=TRUE)

compare(m6, m5)

'''Model 7- Attempt to see if hike distance is worth modeling '''

#problematic to estimate heavy hike effect on top of distance
#could try to estimate effect only for certain types of hikes

distance_matters <- dat$special_category == 'regular' & !is.na(dat$distance_km) 
sum(distance_matters)
dt <- dat[distance_matters,]

MHD <- mean(dt$distance_km)
SDHD <- sd(dt$distance_km)

dat$distance_std <- (dat$distance_km - MHD)/SDHD

hist(dat$distance_std[distance_matters])

plot(dt$distance_km, dt$signups) 
plot(dat$distance_std, dat$signups)

idx <- which(is.na(dat$distance_std))
dat$distance_std[idx] <- 0

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  is_winter= dat$is_winter,
  is_2022= dat$is_2022,
  last_hike= dat$date_last_hike,
  is_sunday= dat$dow,
  morning_start= as.integer(morning_start),
  distance_matters= as.integer(distance_matters),
  start_time= dat$start_time_std,
  distance= dat$distance_std
)

m7 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + r*rain + y*is_2022 + w*is_winter + es*morning_start*start_time + dow*is_sunday + wlh*last_hike + d*distance_matters*distance,
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.25),
    sigma ~ half_normal(0, 0.5),
    y ~ dnorm(0, 0.5),
    dow ~ dnorm(0, 0.3),
    w ~ dnorm(0, 0.3),
    es ~ dnorm(0, 0.3),
    d ~ dnorm(0, 0.3),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    wlh ~ dnorm(0, 0.3),
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

precis(m7, depth=2)

post <- extract.samples(m7)

dens(post$wlh)
dens(post$d)

compare(m7, m6, m5) #not much effect it seems






