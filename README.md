# Hiking Data Project
This is a set of STAN model specifications for Bayesian models of signup numbers to hikes in my local hiking group as a function of various predictors (weather, distance, season, type of hike etc). R scripts are for data pre-processing steps and analysing the MCMC output. The source data is not part of this repository for privacy reasons.

I compiled the STAN models using the CmdStanR package interface.

# Data Pre-processing

I gathered all the data myself from the signup list and event descriptions in my hiking group's WhatsApp chat. There are 155 hikes in the data between March 2022 and June 2026. I sourced historical weather data from MeteoStat. 

I did some basic data quality control (data_preparation.R), and converted date and starting time of each hike from character strings to R's datetime format using the lubridate package. I exported the resulting dataframe as an RDS file for easy access in all my subsequent analyses.


