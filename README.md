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

# 'Tis the Season, Or Not...

There are many reasons to expect a seasonal effect. Exams, start or end of contracts, people going on holiday- these factors (potentially) change the pool of people who are able or willing to join hikes. I tried to fit some simple models lumping different months of the year together to explore this possibility. Model 1 (m4.1) uses 6 pairs of 2 consecutive months starting from january, m4.2 4 seasons of 3 months each starting from december, m4.3 3 seasons of 4 months each starting from november, and m4.4 2 seasons of 6 months each starting from october. 

| model | WAIC  | SE    | dWAIC | dSE  | pWAIC | weight |
|-------|-------|-------|-------|------|-------|--------|
| m3.1  | 930.8 | 20.58 | 0     | NA   | 8.6   | 0.48   |
| m4.4  | 932.7 | 20.41 | 1.9   | 1.02 | 9.5   | 0.18   |
| m4.3  | 933.0 | 20.02 | 2.2   | 2.44 | 10.3  | 0.16   |
| m4.2  | 933.2 | 20.45 | 2.4   | 2.64 | 10.7  | 0.14   |
| m4.1  | 936.2 | 20.30 | 5.4   | 2.28 | 11.8  | 0.03   |

In comparison with a simpler model that doesn't include seasonal effects, none of the seasonal models performed as well as I'd hoped. A comparison between the prior and posterior shows not much has been learned from the data about seasonal effects. Based on posterior summaries, it seems seasonal effects are partially confounded by type of hike, and including seasonal effects increases the uncertainty in the effect of hike type. I checked the serial autocorrelation plot between successive hikes in the data ordered by date, and it seems this correlation declines quite rapidly over 1 or 2 successive hikes.

# The Gap of Time Between Hikes and the Sunday Effect

Grouping hikes by the day of the week on which they happen and plotting a boxplot of signups suggests that hikes on a Sunday are more popular than hikes on a Saturday or any other day of the week. There are 17 hikes on weekdays but signups vary quite a lot. Some of these might be on public holidays, they might be evening hikes or they fall during the summer when people are generally off work. I used a binary indicator variable to estimate the 'Sunday effect'

I also wanted to estimate the effect of a long gap between a hike and the previous one. On the one hand people might be more excited about a hike if there's been a long time since the last one. On the other hand, there might be a momentum effect that's lost when too much time has passed between hikes. I used weeks since last hike centred on 0 as a continuous predictor, where 1 week since the last hike = 0. -1 is then equivalent to a hike on the same day as another hike and 1 is equivalent to a hike two weeks since the last one. 

| model | WAIC  | SE    | dWAIC | dSE  | pWAIC | weight |
|-------|-------|-------|-------|------|-------|--------|
| m6    | 929.3 | 19.92 | 0     | NA   | 10.4  | 0.68   |
| m3.1  | 930.8 | 20.39 | 1.5   | 4.18 | 8.6   | 0.32   |

The predictors improve model fit and comparing prior and posterior suggests the data do support the Sunday effect and a positive effect of a longer gap between hikes, though the posterior is still consistent with very minor or zero effect sizes as well as larger effect sizes.
