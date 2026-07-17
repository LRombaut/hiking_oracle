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
| m2    | 932.5 | 20.77  | 0     | NA  | 7.8   | 1      |
| m1    | 1415.1 | 122.10 | 482.6   | 104.38 | 51.6  | 0      |

Calculating PSIS scores for model 1 showed that 9 data points had Pareto k values greater than 0.5. There was one such outlier for model 2. 

I used a Gamma-Poisson count model as the basis for all subsequent analyses.

# Rain, Rain, Everyday!

Rain was a strong candidate predictor for signups. There were 52 hikes with at least some rainfall. I used historical hourly rainfall data for the weather station closest to the hike's location from MeteoStat. I manually recorded the peak hourly precipitation in mm between the hours of 9am and 6pm for all hikes except the night hikes.

I tried three different ways of modeling the effect of rain. Model 1 (m3.1) uses a binary 'rain' (>0 mm) vs. 'no rain' (0 mm) indicator variable. Model 2 (m3.2) uses separate indicator variables for 'light rain' (<= 0.5 mm) and 'heavy rain' (> 0.5 mm). Model 3 (m3.3) treats peak hourly precipitation in mm as a continuous predictor in the regression model.

| model | WAIC  | SE    | dWAIC | dSE  | pWAIC | weight |
|-------|-------|-------|-------|------|-------|--------|
| m3.1  | 931.5 | 20.48 | 0     | NA   | 8.9   | 0.57   |
| m3.2  | 933.0 | 20.66 | 1.5   | 0.64 | 9.5   | 0.27   |
| m3.3  | 934.1 | 21.09 | 2.6   | 3.40 | 8.4   | 0.16   |

The simplest model is the most strongly supported by the WAIC measure, and has the advantage of being the easiest to interpret. I therefore decided to use a binary indicator variable for rain in subsequent models. 

