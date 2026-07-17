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
  geom_smooth()

modlm <- lm(signups ~ date_last_hike, data=dat)
summary(modlm)
plot(modlm)
#try nonlinear association
dat$lh2 <- dat$date_last_hike^2
modlm5 <- lm(signups ~ date_last_hike + lh2, data=dat)
summary(modlm5) #not promising
plot(modlm5)


'''Model 5 Common effect for weeks since last hike'''

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  weeks_last_hike= dat$date_last_hike
)

m5 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + r*rain + wlh*weeks_last_hike,
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.25),
    sigma ~ half_normal(0, 0.5),
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    wlh ~ dnorm(0, 0.3),
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

precis(m5, depth=2)
#chain diagnostics and posterior summary
traceplot(m5, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r', 'wlh'), window=c(200,1000))
trankplot(m5, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r', 'wlh'), window=c(200,1000))

#prior-posterior comparison

m5.prior <- extract.prior(m5)
m5.post <- extract.samples(m5)
dens(m5.post$wlh, xlim=c(-0.5,0.5))
dens(m5.prior$wlh, col='red', add=TRUE) #some evidence of an effect of weeks since the last hike

dens(m5.post$r, xlim=c(-0.5,0.5))
dens(m5.prior$r, col='red', add=TRUE) #some evidence of an effect of rain

#prior-posterior comparisons
N <- 2000
dens(m5.prior$a_bar)
dens(m5.post$a_bar, col='red', add=TRUE)
dens(m5.prior$sigma)
dens(m5.post$sigma, col='red', add=TRUE)
dens(m5.prior$phi)
dens(m5.post$phi, col='red', add=TRUE)
a.prior <- rnorm(N, mean=m5.prior$a_bar, sd=m5.prior$sigma) 
a.post <- rnorm(N, mean=m5.post$a_bar, sd=m5.post$sigma)
lambda.prior <- exp(a.prior)
lambda.post <- exp(a.post)
dens(a.prior)
dens(a.post, col='red', add=TRUE)
dens(lambda.prior, adj=0.5, xlim=c(0,100))
dens(lambda.post, adj=0.5, col="red", add=TRUE)

a <- exp(m5.post$a)
dens(a[,1], xlim=c(0,100), ylim=c(0,0.3))
dens(a[,2], add=TRUE)
dens(a[,3], add=TRUE)
dens(a[,4], add=TRUE)
dens(a[,5], add=TRUE)
dens(a[,6], add=TRUE)
dens(a[,7], add=TRUE)
dens(lambda.prior, col="red", add=TRUE)

#posterior predictive checks
m5.pred <- link(m5)
mu_pred <- apply(m5.pred, 2, mean)

plot( dat$signups ~ mu_pred , col=rangi2 , xlim=c(0,60),
      xlab='predicted signups', ylab='observed signups')
abline(a=0, b=1, lty=2)
cor(dat$signups, mu_pred)

levels(as.factor(dat$special_category))
simdat <- list(
  weeks_last_hike= seq(-1,3,length.out=50),
  rain= rep(0,50), #no rain
  typeid= rep(6,50) #regular hikes
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
  weeks_last_hike= seq(-1,4,length.out=50),
  rain= rep(1,50), #with rain
  typeid= rep(6,50) #regular hikes
)

sims <- sim(m5, data=simdat2)
simpred <- link(m5, data=simdat2)

mu_pred <- apply(simpred, 2, mean)
mu_PI <- apply(simpred, 2, PI)
pred_PI <- apply(sims, 2, PI)

lines(wlh, mu_pred, col='blue')
shade(mu_PI, wlh, col=col.alpha('blue', alpha=0.2)) 

'''Model 6 Common effect for weeks since last hike'''

dow <- weekdays(dat$date)
table(dow)

for(i in 1:length(dow)){
  dow[i] <- ifelse(dow[i] == "Sunday", 1, 0)
}
table(dow)

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category)),
  rain= dat$rain_level,
  weeks_last_hike= dat$date_last_hike,
  sunday= as.integer(dow)
)

m6 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid] + dow*sunday + r*rain + wlh*weeks_last_hike,
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.25),
    sigma ~ half_normal(0, 0.5),
    dow ~ dnorm(0, 0.3), #sunday effect
    r ~ dnorm(0, 0.3), #turnout with rain could be anywhere between 55% to 180% of turnout with no rain
    wlh ~ dnorm(0, 0.3), #weeks since last hike centered on 0 for 1 week since last hike
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

precis(m6, depth=2)
#chain diagnostics and posterior summary
a_params <- paste0('a[',as.character(1:7),']')
traceplot(m6, pars=c(a_params, 'dow', 'a_bar', 'sigma', 'phi', 'r', 'wlh'), window=c(200,1000))
trankplot(m6, pars=c(a_params, 'dow', 'a_bar', 'sigma', 'phi', 'r', 'wlh'), window=c(200,1000))

#prior-posterior comparison

m6.prior <- extract.prior(m6)
m6.post <- extract.samples(m6)

dens(m6.post$wlh, xlim=c(-0.3,0.3))
dens(m6.prior$wlh, col='red', add=TRUE) #some evidence of an effect of weeks since the last hike

dens(m6.post$r, xlim=c(-0.5,0.5))
dens(m6.prior$r, col='red', add=TRUE) #some evidence of an effect of rain

dens(m6.post$dow)
dens(m6.prior$dow, col='red', add=TRUE)

#prior-posterior comparisons
N <- 2000
dens(m6.prior$a_bar)
dens(m6.post$a_bar, col='red', add=TRUE)
dens(m6.prior$sigma)
dens(m6.post$sigma, col='red', add=TRUE)
dens(m6.prior$phi)
dens(m6.post$phi, col='red', add=TRUE)
a.prior <- rnorm(N, mean=m6.prior$a_bar, sd=m6.prior$sigma) 
a.post <- rnorm(N, mean=m6.post$a_bar, sd=m6.post$sigma)
lambda.prior <- exp(a.prior)
lambda.post <- exp(a.post)
dens(a.prior)
dens(a.post, col='red', add=TRUE)
dens(lambda.prior, adj=0.5, xlim=c(0,100))
dens(lambda.post, adj=0.5, col="red", add=TRUE)

a <- exp(m6.post$a)
dens(a[,1], xlim=c(0,100), ylim=c(0,0.3))
dens(a[,2], add=TRUE)
dens(a[,3], add=TRUE)
dens(a[,4], add=TRUE)
dens(a[,5], add=TRUE)
dens(a[,6], add=TRUE)
dens(a[,7], add=TRUE)
dens(lambda.prior, col="red", add=TRUE)

#posterior predictive checks
m6.pred <- link(m6)
mu_pred <- apply(m6.pred, 2, mean)

plot( dat$signups ~ mu_pred , col=rangi2 , xlim=c(0,60),
      xlab='predicted signups', ylab='observed signups')
abline(a=0, b=1, lty=2)
cor(dat$signups, mu_pred)


compare(m3.1,m6)

stancode(m6)

