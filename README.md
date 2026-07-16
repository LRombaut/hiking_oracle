# Hiking Data Project
This is a set of Stan model specifications for Bayesian models of signup numbers to hikes in my local hiking group as a function of various predictors (weather, distance, season, type of hike etc). R scripts are for data pre-processing steps and analysing the MCMC output. The source data is not part of this repository for privacy reasons.

I compiled the STAN models using the CmdStanR package interface.

# Data Pre-processing

I gathered all the data myself from the signup list and event descriptions in my hiking group's WhatsApp chat. There are 155 hikes in the data between March 2022 and June 2026. I sourced historical weather data from MeteoStat.

I did some basic data quality control (data_preparation.R), and converted date and starting time of each hike from character strings to POSIXct format using the lubridate package. I removed hikes which had a signup number cap, leaving 124 hikes. I exported the resulting dataframe as an RDS file for easy access in all my subsequent analyses.

# Overdispersed Counts

The first model comparison I did was to gauge whether a Poisson count model (m1.stan) was adequate to describe the dispersion in signups for each category of hike, or whether a Gamma-Poisson (negative binomial) model (m2.stan) was necessary to model overdispersion. The comparison of WAIC between these two models shows strong support for the second model with overdispersion:

| model | WAIC | SE  | dWAIC | dSE | pWAIC | weight |
|-------|------|-----|-------|-----|-------|--------|
| m2    | 932.7 | 20.83  | 0     | NA  | 7.9   | 1      |
| m1    | 1414.9 | 122.11 | 482.2   | 104.32 | 51.1  | 0      |

Calculating PSIS scores for model 1 showed that 4 data points had Pareto k values greater than 0.5. There was one such outlier for model 2.   


