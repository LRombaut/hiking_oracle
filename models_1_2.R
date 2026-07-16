rm(list=ls())
library(rethinking)
set.seed(497)

dat <- readRDS("hikes.RDS")
rownames(dat) <- seq(1,length(dat$date))

d <- list(
  signups= dat$signups,
  typeid= as.numeric(as.factor(dat$special_category))
)

'''Model 1: Poisson Count Model'''

#prior predictive check 

N <- 2000
sigma <- rexp(N, rate=2)
a_bar <- rnorm(N, mean=3, sd=0.5)
dens(sigma)
dens(a_bar)

a_prior <- rnorm(N, mean=a_bar, sd=sigma)
lambda <- exp(a_prior)

dens(a_prior)
dens(lambda, xlim=c(0,100))


#poisson count model specification
m1 <- ulam(
  alist(
    signups ~ dpois(lambda),
    log(lambda) <- a[typeid],
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.5),
    sigma ~ dexp(2)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

stancode(m1)

#chain diagnostics and posterior summary
traceplot(m1, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma'), window=c(200,1000))
trankplot(m1, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma'), window=c(200,1000))

precis(m1, depth=2)
levels(as.factor(dat$special_category)) 
psis <- PSIS(m1, pointwise=TRUE)

sum(psis$k > 0.5)

#prior-posterior comparisons
N <- 2000
m1.post <- extract.samples(m1)
m1.prior <- extract.prior(m1, n=N)
a.prior <- rnorm(N, mean=m1.prior$a_bar, sd=m1.prior$sigma) 
a.post <- rnorm(N, mean=m1.post$a_bar, sd=m1.post$sigma)
lambda.prior <- exp(a.prior)
lambda.post <- exp(a.post)
dens(a.prior)
dens(a.post, col='red', add=TRUE)
dens(lambda.prior, adj=0.5, xlim=c(0,100))
dens(lambda.post, adj=0.5, col="red", add=TRUE)

a <- exp(m1.post$a)
dens(a[,1], xlim=c(0,100), ylim=c(0,0.8))
dens(a[,2], add=TRUE)
dens(a[,3], add=TRUE)
dens(a[,4], add=TRUE)
dens(a[,5], add=TRUE)
dens(a[,6], add=TRUE)
dens(a[,7], add=TRUE)
dens(lambda.prior, col="red", add=TRUE)

#posterior predictive check
mu <- link(m1)
mu_mean <- apply(mu, 2, mean)

plot( dat$signups ~ mu_mean , col=rangi2 , xlim=c(0,60),
      xlab='predicted signups', ylab='observed signups')
abline(a=0, b=1, lty=2)


'''Model 2: Gamma-Poisson Count Model'''

#prior predictive check 

curve(dexp(x,rate=0.5), from=0, to=5, ylim=c(0,1))

counts.p <- rpois(1e4, lambda=exp(3))
counts.gp <- rgampois(1e4, mu=exp(3), scale=3.42)

par(mfrow=c(2,1))
hist(counts.p, breaks=100, xlim=c(0,100))
hist(counts.gp, breaks=100, xlim=c(0,100))

#model specification
m2 <- ulam(
  alist(
    signups ~ dgampois(lambda, phi),
    log(lambda) <- a[typeid],
    a[typeid] ~ dnorm(a_bar, sigma),
    a_bar ~ dnorm(3, 0.5),
    sigma ~ dexp(2),
    phi ~ dexp(0.5)
  ), 
  data=d, chains=4, cores=4, log_lik = TRUE
)

stancode(m2)

#chain diagnostics and posterior summary
traceplot(m2, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi'), window=c(200,1000))
trankplot(m2, pars=c('a[1]','a[2]','a[3]','a[4]','a[5]','a[6]','a[7]', 'a_bar', 'sigma', 'phi'), window=c(200,1000))

precis(m2, depth=2)
levels(as.factor(dat$special_category)) 
psis2 <- PSIS(m2, pointwise=TRUE) # no Pareto k values greater than 0.5 

sum(psis2$k > 0.5)

#prior-posterior comparisons
N <- 2000
m2.post <- extract.samples(m2)
m2.prior <- extract.prior(m2, n=N)
a.prior <- rnorm(N, mean=m2.prior$a_bar, sd=m2.prior$sigma) 
a.post <- rnorm(N, mean=m2.post$a_bar, sd=m2.post$sigma)
lambda.prior <- exp(a.prior)
lambda.post <- exp(a.post)
dens(a.prior)
dens(a.post, col='red', add=TRUE)
dens(lambda.prior, adj=0.5, xlim=c(0,500))
dens(lambda.post, adj=0.5, col="red", add=TRUE)

dens(m2.prior$sigma, ylim=c(0,5))
dens(m2.post$sigma, col="red", add=TRUE)

dens(m2.prior$phi, ylim=c(0,1))
dens(m2.post$phi, col="red", add=TRUE)

a <- exp(m2.post$a)
dens(a[,1], xlim=c(0,100), ylim=c(0,0.8))
dens(a[,2], add=TRUE)
dens(a[,3], add=TRUE)
dens(a[,4], add=TRUE)
dens(a[,5], add=TRUE)
dens(a[,6], add=TRUE)
dens(a[,7], add=TRUE)
dens(lambda.prior, col="red", add=TRUE)

#posterior predictive check
mu <- link(m2)
mu_mean <- apply(mu, 2, mean)

plot( dat$signups ~ mu_mean , col=rangi2 , xlim=c(0,60),
      xlab='predicted signups', ylab='observed signups')
abline(a=0, b=1, lty=2)


''' Model Comparison Models 1 and 2 '''

compare(m1, m2) # model 2 strongly favoured

precis(m1, depth=2)
precis(m2, depth=2)




