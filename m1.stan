data{
    array[124] int signups;
    array[124] int typeid;
}
parameters{
     vector[7] a;
     real a_bar;
     real<lower=0> sigma;
}
model{
     vector[124] lambda;
    sigma ~ exponential( 2 );
    a_bar ~ normal( 3 , 0.5 );
    a ~ normal( a_bar , sigma );
    for ( i in 1:124 ) {
        lambda[i] = a[typeid[i]];
        lambda[i] = exp(lambda[i]);
    }
    signups ~ poisson( lambda );
}
generated quantities{
    vector[124] log_lik;
     vector[124] lambda;
    for ( i in 1:124 ) {
        lambda[i] = a[typeid[i]];
        lambda[i] = exp(lambda[i]);
    }
    for ( i in 1:124 ) log_lik[i] = poisson_lpmf( signups[i] | lambda[i] );
}
