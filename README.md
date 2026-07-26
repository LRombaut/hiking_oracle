# Hiking Oracle Data Project

My local hiking group has existed for 5 years and has done more than 150 hikes. It has grown from a handful of members to a thriving community. Members of the group sign up to hikes via the Whatsapp chat and remove themselves from the signup list if they are no longer coming. Some hikes get more than 50 signups, while other hikes have a much cozier dozen people or so. Since there is a lot of information about each hike recorded in the chat history, I wanted to explore what predicts signup numbers with the goal of gaining insight as well as making predictions about turnout to future hikes. 

I fit a generalised linear model to predict signup counts assuming a Gamma-Poisson mixture process with a negative binomial error distribution and a log link function to the linear predictors. I used a Bayesian modeling approach implemented in the stan programming language to generate posterior distributions of parameter estimates feeding into a predictive model for the distribution of signups. The full model specification and further technical details of my modeling workflow can be found in the sections further down below. 

My reflections on this modeling exercise are in a section all the way down. I have decided to call this predictive model the 'hiking oracle'. Like an oracle, the predictions are vague and the outcomes almost never exactly as expected, but the exercise of making predictions can nonetheless offer some insights into the forces that shape the outcome.

# Insights

The hiking oracle makes predictions that are typically within ~40% of the observed turnout (weighted average percentage error or WAPE of 39.4%) and the predictive distribution does an adequate job of capturing the error of the data around the mean prediction. A significant portion of the difference between what is observed and what is expected here is simply due to the irreducible error of the data generating process, limiting the predictive power of any model that could be fit to the data in principle. It's reasonable to assert that for a typical hike the model will not make more accurate or certain predictions of signup numbers than a hike organiser themselves could provide by experience and intuition alone. In the plot on the right below, the red dashed lines indicate the upper and lower 89% bounds on the mean of the posterior predictions. The shaded regions are the 68% and 95% prediction intervals for observed signups.  

<img width="282" height="372" alt="observed_predicted" src="https://github.com/user-attachments/assets/ca941d6b-a22d-4c05-9523-c259f0442182" />
<img width="250" height="372" alt="observed_predicted" src="https://github.com/user-attachments/assets/bd8c7a34-1ee3-49d4-b9a0-6c9446072960" />

While the hiking oracle may have limited utility as a tool for predicting turnout to any individual hike, in aggregate the model does offer insight into the factors that motivate people's decisions to sign up or not. First there is the type of hike being organised. Most hikes have been local to the area where I live ('regular' hikes). Sometimes we will go in the evening or at night ('night hikes'). Some hikes involve visiting another city to do something cultural ('city trip'). Other times the intention is to experience a cool natural phenomenon such as the annual bloom of bluebells, the Perseid meteor shower, or fireflies at night ('special nature'). Hikes that are particularly grueling are advertised as such ('heavy hikes'). The figure below shows the posterior distributions of the mean expected turnout for different types of hikes. The red dashed line is the Bayesian prior.  

<img width="1826" height="780" alt="hike_type" src="https://github.com/user-attachments/assets/514cdba7-e2f5-4cf8-a614-ba9955953ec1" />

On top of the effect of each specific type of hike there were also other effects influencing hike signups. In the figure below I have plotted the posterior distributions of effect sizes for various predictors included in the model. The effect sizes are the implied percentage changes to the expected number of signups, assuming the effect of all other predictors remains fixed at a certain baseline. For example, the 'Sunday Effect' is whether a hike was organised on a Sunday rather than a Saturday (or any other day of the week). Hikes on a Sunday are expected to have +20% more signups on average. The effect comes with uncertainty however, reflected in the posterior distribution. To capture 89% of the posterior distribution you would have to allow for a Sunday effect between +1% and +40%, though effect sizes closer to +20% are more likely. If there is any rain forecasted at all the number of signups drops by -15% on average. During the winter months the number of signups drops by -16% on average. An early start time also influences people's decisions whether or not to sign up. Few people are motivated enough to get up at 6am to go on a hike on their days off! After everything else is accounted for, the model implies that

<img width="1022" height="948" alt="posteriors" src="https://github.com/user-attachments/assets/7f9e61df-ce5a-4911-9a1b-f84aded08d4b" />

<img width="668" height="764" alt="starting_time" src="https://github.com/user-attachments/assets/439546c2-4879-42c9-843d-521583737ddb" />


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

# 'Tis the Season...Year, Season and Sunday Effects

The hiking group has existed for 5 years. In that time the number of people who are in the group has grown, so has the number of people available to sign up for hikes. To capture this effect I tested three different models. The first model (m4.0) considers the first year (2022) to be different from all subsequent years because the group was just starting up. The second model (m4.1) assumes a linear trend from the year the group was started up to the present. Model 3 (m4.2) gives each year its own individual year effect.

| model | WAIC  | SE    | dWAIC | dSE  | pWAIC | weight |
|-------|-------|-------|-------|------|-------|--------|
| m4.0  | 922.2 | 20.82 | 0     | NA   | 9.6   | 0.89   |
| m4.2  | 930.8 | 20.88 | 4.6   | 1.27 | 11.3  | 0.09   |
| m4.1  | 929.8 | 21.42 | 7.6   | 3.89 | 9.7   | 0.02   |

The simplest model (m4.0) is strongly preferred, implying that the pool of people who sign up to hikes regularly has remained in equilibrium in the years after the group was started. Examining the posterior for m4.2 shows that the individual year effects are uncertain but all centred around 0 except for the year 2022. The plot below uses a loess smoothing to show the trend in the timeseries.

<img width="1268" height="572" alt="timeseries" src="https://github.com/user-attachments/assets/6772f82d-fe5b-4502-80a6-6c9140ff79f8" />

There are many reasons to expect a seasonal effect. Exams, start or end of contracts, people going on holiday- these factors (potentially) change the pool of people who are able or willing to join hikes. I tried to fit some simple models lumping different months of the year together to explore this possibility. Model 1 (m4.0.1) splits the months of the year into four seasons of three months each, m4.0.2 assumes that during the cold winter months people will be less likely to come on hikes compared to the rest of the year, and m4.0.3 assumes that both in the winter months of december, january and february as well as in the summer months of june, july and august people will be less likely to join. 

| model  | WAIC  | SE    | dWAIC | dSE  | pWAIC | weight |
|--------|-------|-------|-------|------|-------|--------|
| m4.0.2 | 919.8 | 20.47 | 0     | NA   | 9.8   | 0.46   |
| m4.0.3 | 920.0 | 21.25 | 0.2   | 4.17 | 10.0  | 0.41   |
| m4.0.1 | 922.5 | 20.97 | 2.7   | 2.82 | 11.8  | 0.12   |

There's a slight difference in WAIC score between models m4.0.2 and m4.0.3, but it's small relative to the error (dSE). In the posterior of model m4.0.1 only the winter effect is reliably negative relative to summer, autumn, and spring effects. I therefore selected model m4.0.2 as the basis for further modeling. 

Grouping hikes by the day of the week on which they happen and plotting a boxplot of signups suggests that hikes on a Sunday are more popular than hikes on a Saturday or any other day of the week. There are 17 hikes on weekdays but signups vary quite a lot. Some of these might be on public holidays, they might be evening hikes or they fall during the summer when people are generally off work. I used a binary indicator variable to estimate the 'Sunday effect' in model m4.0.2.s.

| model    | WAIC  | SE    | dWAIC | dSE  | pWAIC | weight |
|----------|-------|-------|-------|------|-------|--------|
| m4.0.2.s | 917.1 | 20.19 | 0     | NA   | 10.8  | 0.86   |
| m4.0.2   | 920.6 | 20.60 | 3.6   | 3.86 | 10.2  | 0.14   |

# The Gap of Time Between Hikes, Hike Start Time & Distance

The amount of time that has passed since the previous hike in the group seemed to me a reasonable predictor to include in the model (m5). If a hike happens on the same weekend as another hike they might compete for signups, and if a long time has passed without a hike people might be more enthusiastic about joining the next one. 

The hike start time when people are expected to meet up could also be important (m6). People might be reluctant to wake up early to go hiking on a weekend. 

Lastly, the planned hike distance could play a role (m7). To prevent this effect being confounded by the type of hike (some hikes are classed as 'heavy hikes'), I used an indicator variable to make sure that the effect only applies to hikes classed as 'regular' hikes. 

I sequentially added these predictors to see if their inclusion in the model is justified. 

| model | WAIC  | SE    | dWAIC | dSE  | pWAIC | weight |
|-------|-------|-------|-------|------|-------|--------|
| m6    | 916.0 | 20.01 | 0     | NA   | 12.8  | 0.52   |
| m7    | 916.7 | 19.65 | 0.7   | 0.68 | 12.8  | 0.36   |
| m5    | 918.9 | 20.35 | 2.9   | 4.05 | 11.7  | 0.12   |

While including weeks since the last hike does incur a slight penalty, the posterior shows that this effect may well be positive and with more data might be better resolved, so I decided to keep it in the model. There seems to be a reliably negative effect of an early start time. Hike distance for regular hikes does not significantly improve prediction, plus there is already an indicator for 'heavy hikes' in the model so it seems redundant to estimate this effect.    
