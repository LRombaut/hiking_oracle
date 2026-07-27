rm(list=ls())
library(rethinking)
library(wesanderson)

dat <- readRDS("hikes.RDS")
rownames(dat) <- seq(1,length(dat$date))

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
    a_bar ~ dnorm(3, 0.5),
    sigma ~ half_normal(0, 1),
    y ~ dnorm(0, 0.5),
    dow ~ dnorm(0, 0.3),
    w ~ dnorm(0, 0.3),
    es ~ dnorm(0, 0.3),
    r ~ dnorm(0, 0.3), #turnout with any amount of rain could be anywhere between 55% to 180% of turnout with no rain
    wlh ~ dnorm(0, 0.3),
    phi ~ dexp(0.3)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE, iter=3000
)

precis(m6, depth=2)
psis <- PSIS(m6, pointwise=TRUE)
sum(psis$k > 0.5)

#chain diagnostics
traceplot(m6, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r', 'wlh', 'y', 'w', 'dow'), window=c(1000,3000))
trankplot(m6, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi', 'r', 'wlh', 'y', 'w', 'dow'), window=c(1000,3000))

#prior-posterior comparisons

post <- extract.samples(m6)
prior <- extract.prior(m6, n=3000)

dens(post$lambda) #predicted mean 

dens(post$phi) # overdispersion parameter of negative binomial distribution
dens(prior$phi, col='red', add=TRUE)

dens(post$a_bar) #hyperprior mean of intercepts for different types of hike
dens(prior$a_bar, col='red', add=TRUE)

dens(post$sigma) #hyperprior sd of intercept for different types of hike
dens(prior$sigma, col='red', add=TRUE)

dens(post$y) #effect of year 2022
dens(prior$y, col='red', add=TRUE)

dens(exp(post$wlh)) #effect of year 2022
dens(exp(prior$wlh), col='red', add=TRUE)

dens(post$dow) #sunday effect
dens(prior$dow, col='red', add=TRUE)

dens(post$w) #winter effect
dens(prior$w, col='red', add=TRUE)

dens(post$es) #early start time effect
dens(prior$es, col='red', add=TRUE)

dens(post$r) #rain effect
dens(prior$r, col='red', add=TRUE)

#correlation between the posteriors?
par(mar=c(1,1,1,1))
d <- data.frame(es=post$es, w=post$w, y=post$y, dow=post$dow, r=post$r, wlh=post$wlh, phi=post$phi)
d2 <- as.data.frame(post$a)
pairs(d[1:100,])

#plotting posteriors

par(mfrow=c(5,1), mar= c(2,2,2,2))

dens(exp(post$wlh), xlim=c(0.5,1.5), ylim=c(0,7.5), axes=FALSE, ylab='', xlab='')
axis(1, at=seq(0.5,1.5,0.1), labels = c('-50%','-40%','-30%','-20%','-10%','base','+10%','+20%','+30%','+40%','+50%'))
abline(v=1,lty=2)
text(x=0.5, y=6, font=2, pos=4, 'Weeks Since Last Hike')

dens(exp(post$r), xlim=c(0.5,1.5), ylim=c(0,7.5), axes=FALSE, ylab='', xlab='')
axis(1, at=seq(0.5,1.5,0.1), labels = c('-50%','-40%','-30%','-20%','-10%','base','+10%','+20%','+30%','+40%','+50%'))
abline(v=1,lty=2)
text(x=0.5, y=6, font=2, pos=4, 'Rain')

dens(exp(post$es), xlim=c(0.5,1.5), ylim=c(0,7.5), axes=FALSE, ylab='', xlab='')
axis(1, at=seq(0.5,1.5,0.1), labels = c('-50%','-40%','-30%','-20%','-10%','base','+10%','+20%','+30%','+40%','+50%'))
abline(v=1,lty=2)
text(x=0.5, y=6, font=2, pos=4, 'Later Starting Time')

dens(exp(post$dow), xlim=c(0.5,1.5), ylim=c(0,7.5), axes=FALSE, ylab='', xlab='')
axis(1, at=seq(0.5,1.5,0.1), labels = c('-50%','-40%','-30%','-20%','-10%','base','+10%','+20%','+30%','+40%','+50%'))
abline(v=1,lty=2)
text(x=0.5, y=6, font=2, pos=4, 'Sunday Effect')

dens(exp(post$w), xlim=c(0.5,1.5), ylim=c(0,7.5), axes=FALSE, ylab='', xlab='')
axis(1, at=seq(0.5,1.5,0.1), labels = c('-50%','-40%','-30%','-20%','-10%','base','+10%','+20%','+30%','+40%','+50%'))
abline(v=1,lty=2)
text(x=0.5, y=6, font=2, pos=4, 'Winter')

# posterior predictive simulations for the effect of start time

simdat <- list(
  start_time= seq(-2,2,length.out=1000),
  morning_start= rep(1,1000),
  is_sunday=rep(0,1000),
  last_hike=rep(0,1000),
  is_2022=rep(0,1000),
  is_winter=rep(0,1000),
  rain=rep(0,1000),
  typeid=rep(6,1000)
)
  
mus <- link(m6, simdat, n=1000)
mu_means <- apply(mus, 2, mean)
mu_PI <- apply(mus, 2, PI)

preds <- matrix(data=NA, nrow=1000, ncol=length(simdat$start_time))

for( i in 1:ncol(preds)){
  preds[,i] <- rgampois(1000, mu=mu_means[i], scale=post$phi[i])
}

predmu <- apply(preds, 2, mean)
predPI1 <- apply(preds, 2, PI, prob=0.89)
predPI2 <- apply(preds, 2, PI, prob=0.95)
predPI3 <- apply(preds, 2, PI, prob=0.68)

tdat <- data.frame(start_time_std=simdat$start_time,signups=predmu, PI1.low=predPI1[1,], PI1.high=predPI1[2,], PI2.low=predPI2[1,], PI2.high=predPI2[2,], PI3.low=predPI3[1,], PI3.high=predPI3[2,])

ggplot(dat[dat$special_category == 'regular',], aes(x=start_time_std, y=signups))+
  geom_jitter(col=rangi2,pch=1)+
  geom_smooth(data=tdat, aes(x=start_time_std, y=predmu), lty=2)+
  geom_ribbon(data=tdat, aes(x=start_time_std, ymin = PI1.low, ymax= PI1.high), alpha=0.2)+
  geom_ribbon(data=tdat, aes(x=start_time_std, ymin = PI2.low, ymax= PI2.high), alpha=0.2)+
  geom_ribbon(data=tdat, aes(x=start_time_std, ymin = PI3.low, ymax= PI3.high), alpha=0.2)+
  scale_x_continuous(limits=c(-2,1), breaks=c(-1.955, -1.23, -0.51, 0.212, 0.934), labels=c('8:30 am','9:30 am','10:30 am','11:30 am', '12:30 pm'))+
  scale_y_continuous(limits=c(0,46))+
  xlab('starting time')+
  theme_bw()

mus <- link(m6, simdat)


#hike types

N <- 2000
a.prior <- rnorm(N, mean=prior$a_bar, sd=prior$sigma) 
a.post <- rnorm(N, mean=post$a_bar, sd=post$sigma)
lambda.prior <- exp(a.prior)
lambda.post <- exp(a.post)

dens(a.prior)
dens(a.post, col='red', add=TRUE)

dens(lambda.prior, xlim=c(0,100))
dens(lambda.post, col="red", add=TRUE)

#intercepts for each type of hike
a <- exp(post$a)
dens(lambda.prior, col="red", xlim=c(0,70), ylim=c(0,0.25), lty=2, xlab='Mean Expected Signups')
dens(a[,1], col=wes_palettes$Moonrise3[5], add=TRUE)
dens(a[,2], col=wes_palettes$Moonrise3[3], add=TRUE)
dens(a[,3], col=wes_palettes$GrandBudapest1[3], add=TRUE)
dens(a[,4], col=wes_palettes$FantasticFox1[4], add=TRUE)
dens(a[,5], col=wes_palettes$Darjeeling1[1], add=TRUE)
dens(a[,6], col=wes_palettes$Rushmore1[3], add=TRUE)
dens(a[,7], col=wes_palettes$Darjeeling1[5], add=TRUE)

levels(as.factor(dat$special_category))
legend(60, 0.25, bty='n', legend=c('city trip','game','heavy hike','night hike','other special','regular','special nature'),
       fill=c(wes_palettes$Moonrise3[5],wes_palettes$Moonrise3[3],wes_palettes$GrandBudapest1[3],wes_palettes$FantasticFox1[4],wes_palettes$Darjeeling1[1],wes_palettes$Rushmore1[3],wes_palettes$Darjeeling1[5]))

#posterior predictive checks

mu <- link(m6)
mu_mean <- apply(mu, 2, mean)
muPI <- apply(mu, 2, PI)
sims <- sim(m6)

resids <- dat$signups - mu_mean
plot(mu_mean, resids)

par(mfrow=c(3,3))
hist(dat$signups, breaks=15, main=NULL, xlab=NULL, ylab=NULL)
hist(sims[9,], breaks=15)
qqplot(dat$signups, sims[6,])

mus <- seq(1,60,0.01)
phis <- post$phi
preds <- matrix(data=NA, nrow=1000, ncol=length(mus))

for(i in 1:ncol(preds)){
  sims <- rgampois(1000, mus[i], scale=sample(phis,1))
  preds[,i] <- sims
}

predsPI <- apply(preds, 2, PI, prob=0.95)
predsPI2 <- apply(preds, 2, PI, prob=0.975)
predsPI3 <- apply(preds, 2, PI, prob=0.68)
preds_median <- apply(preds, 2, median)

obs_pred <- data.frame(observed= dat$signups, predicted= mu_mean, ymin=muPI[1,], ymax=muPI[2,])
simdat <- data.frame(predicted= mus, median=preds_median, ymin=predsPI[1,], ymax=predsPI[2,])
simdat2 <- data.frame(predicted= mus, ymin=predsPI2[1,], ymax=predsPI2[2,])
simdat3 <- data.frame(predicted= mus, ymin=predsPI3[1,], ymax=predsPI3[2,])

ggplot(data=obs_pred, aes(x=predicted, y=observed))+
  geom_ribbon(data=simdat, aes(x=predicted, ymin=ymin, ymax=ymax), alpha=0.15, inherit.aes = FALSE)+
  #geom_ribbon(data=simdat2, aes(x=predicted, ymin=ymin, ymax=ymax), alpha=0.15, inherit.aes = FALSE)+
  geom_ribbon(data=simdat3, aes(x=predicted, ymin=ymin, ymax=ymax), alpha=0.15, inherit.aes = FALSE)+
  geom_smooth(aes(x=predicted, y=ymin), se=FALSE, lty=2, col='red', lwd=0.5)+
  geom_smooth(aes(x=predicted, y=ymax), se=FALSE, lty=2, col='red', lwd=0.5)+
  geom_abline(slope=1,intercept=0, lty=2)+
  geom_point(col=rangi2, pch=1, size=0.7)+
  xlab('log predicted')+
  ylab('log observed')+
  coord_fixed()+
  scale_x_log10(breaks=c(10,20,30,40,50,60),lim=c(10,70))+
  scale_y_log10(breaks=c(1,5,10,20,30,40,50,60,100),lim=c(1,100))+
  theme_bw()

#calculate predictive accuracy

sum_observed <- sum(dat$signups)
wMAPEs <- abs(dat$signups - mu_mean)
sum(wMAPEs)/sum_observed

MAPEs <- abs(dat$signups - mu_mean)/dat$signups
sum(MAPEs)/124

weights <- dat$signups/sum(dat$signups)

prederr <- data.frame(prediction=mu_mean, error=MAPEs)

ggplot(data=prederr, aes(x=prediction, y=error))+
  geom_point(col=rangi2, pch=1)+
  geom_smooth(method='lm')+
  scale_y_continuous(limits=c(0,2))+
  theme_bw()


