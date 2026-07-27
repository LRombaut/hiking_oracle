data{
    array[124] int signups;
     vector[124] last_hike;
    array[124] int is_sunday;
     vector[124] start_time;
    array[124] int morning_start;
    array[124] int is_winter;
    array[124] int is_2022;
    array[124] int rain;
    array[124] int typeid;
}
parameters{
     vector[7] a;
     real a_bar;
     real<lower=0> sigma;
     real y;
     real dow;
     real w;
     real es;
     real r;
     real wlh;
     real<lower=0> phi;
}
model{
     vector[124] lambda;
    phi ~ exponential( 0.3 );
    wlh ~ normal( 0 , 0.3 );
    r ~ normal( 0 , 0.3 );
    es ~ normal( 0 , 0.3 );
    w ~ normal( 0 , 0.3 );
    dow ~ normal( 0 , 0.3 );
    y ~ normal( 0 , 0.5 );
    sigma ~ normal( 0 , 1 );
    a_bar ~ normal( 3 , 0.5 );
    a ~ normal( a_bar , sigma );
    for ( i in 1:124 ) {
        lambda[i] = a[typeid[i]] + r * rain[i] + y * is_2022[i] + w * is_winter[i] + es * morning_start[i] * start_time[i] + dow * is_sunday[i] + wlh * last_hike[i];
        lambda[i] = exp(lambda[i]);
    }
    signups ~ neg_binomial_2( lambda , phi );
}
generated quantities{
    vector[124] log_lik;
     vector[124] lambda;
    for ( i in 1:124 ) {
        lambda[i] = a[typeid[i]] + r * rain[i] + y * is_2022[i] + w * is_winter[i] + es * morning_start[i] * start_time[i] + dow * is_sunday[i] + wlh * last_hike[i];
        lambda[i] = exp(lambda[i]);
    }
    for ( i in 1:124 ) log_lik[i] = neg_binomial_2_lpmf( signups[i] | lambda[i] , phi );
}
