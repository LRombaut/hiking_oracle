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
tbl <- tibble(
  date= dat$date,
  signups= dat$signups,
  key= dat$hike_id
)
ts <- as_tsibble(tbl, index=date, key=key, regular=FALSE)

ggplot(data= ts, aes(x= date, y= signups))+
  geom_line()+
  labs(x='Date', y='Signups')


plot_seasonal_diagnostics(ts, .date_var = date, .value = signups, .feature_set = "year")
#august, september and december are lean months/ april stands out because it has the hyacinths and blossom hikes
plot_seasonal_diagnostics(ts, .date_var = date, .value = signups, .feature_set = "month.lbl")
#hikes on sunday seem to have more signups than those on saturday/ on other days of the week fewer hikes have been organised but when they happen lots of people show up (probs a holiday effect)
plot_seasonal_diagnostics(ts, .date_var = date, .value = signups, .feature_set = "wday.lbl")

acf(ts$signups, lag.max=20) #slight correlation between successive hike turnouts

''' Model 4.1: Seasonality per 2 month period '''

month <- as.integer(dat$month)
months2 <- integer(length=124L)
for(i in 1:length(month)){
  months2[i] <- switch(month[i], 1,1,2,2,3,3,4,4,5,5,6,6 )
}
hist(months2, breaks=50)
dat$months2 <- months2

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  monthid= dat$months2
)

#model specification
m4.1 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + b[monthid] + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    b[monthid] ~ dnorm(0, 0.2), #season adds to the effect of hike type
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

#chain diagnostics
precis(m4.1, depth=2)
a_params <- paste0('a[',as.character(1:7),']')
b_params <- paste0('b[',as.character(1:6),']')
traceplot(m4.1, pars=c(a_params, b_params,'a_bar', 'sigma_a', 'phi', 'r'), window=c(200,1000))
trankplot(m4.1, pars=c(a_params, b_params,'a_bar', 'sigma_a', 'phi', 'r'), window=c(200,1000))

psis <- PSIS(m4.1, pointwise=TRUE) 
sum(psis$k > 0.5)

#prior-posterior comparisons
N <- 2000
m4.1.post <- extract.samples(m4.1)
m4.1.prior <- extract.prior(m4.1, n=N)
dens(m4.1.prior$a_bar)
dens(m4.1.post$a_bar, col='red', add=TRUE)
dens(m4.1.prior$sigma_a)
dens(m4.1.post$sigma_a, col='red', add=TRUE)
dens(m4.1.prior$phi)
dens(m4.1.post$phi, col='red', add=TRUE)
a.prior <- rnorm(N, mean=m4.1.prior$a_bar, sd=m4.1.prior$sigma_a) 
a.post <- rnorm(N, mean=m4.1.post$a_bar, sd=m4.1.post$sigma_a)
lambda.prior <- exp(a.prior)
lambda.post <- exp(a.post)
dens(a.prior)
dens(a.post, col='red', add=TRUE)
dens(lambda.prior, adj=0.5, xlim=c(0,100))
dens(lambda.post, adj=0.5, col="red", add=TRUE)

a <- exp(m4.1.post$a)
dens(a[,1], xlim=c(0,70), ylim=c(0,0.25))
dens(a[,2], add=TRUE)
dens(a[,3], add=TRUE)
dens(a[,4], add=TRUE)
dens(a[,5], add=TRUE)
dens(a[,6], add=TRUE)
dens(a[,7], add=TRUE)
dens(lambda.prior, col="red", add=TRUE)

b <- m4.1.post$b
dens(b[,1])
dens(b[,2], add=TRUE)
dens(b[,3], add=TRUE)
dens(b[,4], add=TRUE)
dens(b[,5], add=TRUE)
dens(b[,6], add=TRUE)
dens(m4.1.prior$b, col="red", add=TRUE) #not much has been learned- posterior very similar to prior

'''Model 4.2 - 4 Seasons of 3 months each'''

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
  monthid= dat$months3
)

#model specification
m4.2 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + b[monthid] + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    b[monthid] ~ dnorm(0, 0.2), #season adds to the effect of hike type
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

#chain diagnostics
precis(m4.2, depth=2)
a_params <- paste0('a[',as.character(1:7),']')
b_params <- paste0('b[',as.character(1:4),']')
traceplot(m4.2, pars=c(a_params, b_params,'a_bar', 'sigma_a', 'phi', 'r'), window=c(200,1000))
trankplot(m4.2, pars=c(a_params, b_params,'a_bar', 'sigma_a', 'phi', 'r'), window=c(200,1000))

psis <- PSIS(m4.2, pointwise=TRUE) 
sum(psis$k > 0.5)

#prior-posterior comparisons
N <- 2000
m4.2.post <- extract.samples(m4.2)
m4.2.prior <- extract.prior(m4.2, n=N)
dens(m4.2.prior$a_bar)
dens(m4.2.post$a_bar, col='red', add=TRUE)
dens(m4.2.prior$sigma_a)
dens(m4.2.post$sigma_a, col='red', add=TRUE)
dens(m4.2.prior$phi)
dens(m4.2.post$phi, col='red', add=TRUE)
a.prior <- rnorm(N, mean=m4.2.prior$a_bar, sd=m4.2.prior$sigma_a) 
a.post <- rnorm(N, mean=m4.2.post$a_bar, sd=m4.2.post$sigma_a)
lambda.prior <- exp(a.prior)
lambda.post <- exp(a.post)
dens(a.prior)
dens(a.post, col='red', add=TRUE)
dens(lambda.prior, adj=0.5, xlim=c(0,100))
dens(lambda.post, adj=0.5, col="red", add=TRUE)

a <- exp(m4.2.post$a)
dens(a[,1], xlim=c(0,70), ylim=c(0,0.25))
dens(a[,2], add=TRUE)
dens(a[,3], add=TRUE)
dens(a[,4], add=TRUE)
dens(a[,5], add=TRUE)
dens(a[,6], add=TRUE)
dens(a[,7], add=TRUE)
dens(lambda.prior, col="red", add=TRUE)

b <- m4.2.post$b
dens(b[,1])
dens(b[,2], add=TRUE)
dens(b[,3], add=TRUE)
dens(b[,4], add=TRUE)
dens(m4.2.prior$b, col="red", add=TRUE) #not much has been learned- posterior very similar to prior

'''Model 4.3 - 3 Seasons of 4 months each'''

month <- as.integer(dat$month)
months4 <- integer(length=124L)
for(i in 1:length(month)){
  months4[i] <- switch(month[i], 1,1,2,2,2,2,3,3,3,3,1,1 ) #3 seasons starting november, december, january, february...
}
hist(months4, breaks=50)
dat$months4 <- months4

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  monthid= dat$months4
)

#model specification
m4.3 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + b[monthid] + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    b[monthid] ~ dnorm(0, 0.2), #season adds to the effect of hike type
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

#chain diagnostics
precis(m4.3, depth=2)
a_params <- paste0('a[',as.character(1:7),']')
b_params <- paste0('b[',as.character(1:3),']')
traceplot(m4.3, pars=c(a_params, b_params,'a_bar', 'sigma_a', 'phi', 'r'), window=c(200,1000))
trankplot(m4.3, pars=c(a_params, b_params,'a_bar', 'sigma_a', 'phi', 'r'), window=c(200,1000))

psis <- PSIS(m4.3, pointwise=TRUE) 
sum(psis$k > 0.5)

#prior-posterior comparisons
N <- 2000
m4.3.post <- extract.samples(m4.3)
m4.3.prior <- extract.prior(m4.3, n=N)
dens(m4.3.prior$a_bar)
dens(m4.3.post$a_bar, col='red', add=TRUE)
dens(m4.3.prior$sigma_a)
dens(m4.3.post$sigma_a, col='red', add=TRUE)
dens(m4.3.prior$phi)
dens(m4.3.post$phi, col='red', add=TRUE)
a.prior <- rnorm(N, mean=m4.3.prior$a_bar, sd=m4.3.prior$sigma_a) 
a.post <- rnorm(N, mean=m4.3.post$a_bar, sd=m4.3.post$sigma_a)
lambda.prior <- exp(a.prior)
lambda.post <- exp(a.post)
dens(a.prior)
dens(a.post, col='red', add=TRUE)
dens(lambda.prior, adj=0.5, xlim=c(0,100))
dens(lambda.post, adj=0.5, col="red", add=TRUE)

a <- exp(m4.3.post$a)
dens(a[,1], xlim=c(0,70), ylim=c(0,0.25))
dens(a[,2], add=TRUE)
dens(a[,3], add=TRUE)
dens(a[,4], add=TRUE)
dens(a[,5], add=TRUE)
dens(a[,6], add=TRUE)
dens(a[,7], add=TRUE)
dens(lambda.prior, col="red", add=TRUE)

b <- m4.3.post$b
dens(b[,1])
dens(b[,2], add=TRUE)
dens(b[,3], add=TRUE)
dens(m4.3.prior$b, col="red", add=TRUE) #not much has been learned- posterior very similar to prior, maybe slight effect of the cold season

'''Model 4.4 - 2 Seasons of 6 months each'''

month <- as.integer(dat$month)
months6 <- integer(length=124L)
for(i in 1:length(month)){
  months6[i] <- switch(month[i], 1,1,1,2,2,2,2,2,2,1,1,1 ) #2 seasons starting october, november, december, january, february, march...
}
hist(months6, breaks=50)
dat$months6 <- months6

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  monthid= dat$months6
)

#model specification
m4.4 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + b[monthid] + r*rain, #cross-classified design
    a[typeid] ~ dnorm(a_bar, sigma_a),
    b[monthid] ~ dnorm(0, 0.2), #season adds to the effect of hike type
    a_bar ~ dnorm(3, 0.25),
    sigma_a ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

#chain diagnostics
precis(m4.4, depth=2)
a_params <- paste0('a[',as.character(1:7),']')
b_params <- paste0('b[',as.character(1:2),']')
traceplot(m4.4, pars=c(a_params, b_params,'a_bar', 'sigma_a', 'phi', 'r'), window=c(200,1000))
trankplot(m4.4, pars=c(a_params, b_params,'a_bar', 'sigma_a', 'phi', 'r'), window=c(200,1000))

psis <- PSIS(m4.4, pointwise=TRUE) 
sum(psis$k > 0.5)

#prior-posterior comparisons
N <- 2000
m4.4.post <- extract.samples(m4.4)
m4.4.prior <- extract.prior(m4.4, n=N)
dens(m4.4.prior$a_bar)
dens(m4.4.post$a_bar, col='red', add=TRUE)
dens(m4.4.prior$sigma_a)
dens(m4.4.post$sigma_a, col='red', add=TRUE)
dens(m4.4.prior$phi)
dens(m4.4.post$phi, col='red', add=TRUE)
a.prior <- rnorm(N, mean=m4.4.prior$a_bar, sd=m4.4.prior$sigma_a) 
a.post <- rnorm(N, mean=m4.4.post$a_bar, sd=m4.4.post$sigma_a)
lambda.prior <- exp(a.prior)
lambda.post <- exp(a.post)
dens(a.prior)
dens(a.post, col='red', add=TRUE)
dens(lambda.prior, adj=0.5, xlim=c(0,100))
dens(lambda.post, adj=0.5, col="red", add=TRUE)

a <- exp(m4.4.post$a)
dens(a[,1], xlim=c(0,70), ylim=c(0,0.25))
dens(a[,2], add=TRUE)
dens(a[,3], add=TRUE)
dens(a[,4], add=TRUE)
dens(a[,5], add=TRUE)
dens(a[,6], add=TRUE)
dens(a[,7], add=TRUE)
dens(lambda.prior, col="red", add=TRUE)

b <- m4.4.post$b
dens(b[,1])
dens(b[,2], add=TRUE)
dens(m4.4.prior$b, col="red", add=TRUE) #not much has been learned- posterior very similar to prior, maybe slight effect of the cold season

'''Model Comparison '''

compare(m3.1,m4.1,m4.2,m4.3,m4.4)



