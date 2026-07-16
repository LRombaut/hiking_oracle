data{
    array[124] int signups;
    array[124] int typeid;
}
parameters{
     vector[7] a;
     real a_bar;
     real<lower=0> sigma;
     real<lower=0> phi;
}
model{
     vector[124] lambda;
    phi ~ exponential( 0.5 );
    sigma ~ exponential( 2 );
    a_bar ~ normal( 3 , 0.5 );
    a ~ normal( a_bar , sigma );
    for ( i in 1:124 ) {
        lambda[i] = a[typeid[i]];
        lambda[i] = exp(lambda[i]);
    }
    signups ~ neg_binomial_2( lambda , phi );
}
generated quantities{
    vector[124] log_lik;
     vector[124] lambda;
    for ( i in 1:124 ) {
        lambda[i] = a[typeid[i]];
        lambda[i] = exp(lambda[i]);
    }
    for ( i in 1:124 ) log_lik[i] = neg_binomial_2_lpmf( signups[i] | lambda[i] , phi );
}
