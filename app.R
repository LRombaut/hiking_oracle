
library(shiny)
library(bslib)

#load posterior distribution
post <- readRDS('model_posterior.RDS')

# create user interface ----
ui <- page_sidebar(
  
  title = "Hiking Oracle",
  theme= bs_theme(preset= "journal"),
  # Sidebar panel for inputs 
  sidebar = sidebar(
    # Input: Slider for the Starting Time
    dateInput(
      inputId= "date",
      label= "Date of Hike" ,
      value = NULL, #use current date in client time zone
      min = "2022-01-01",
      max = "2029-12-25",
      format = "yyyy-mm-dd",
      startview = "month",
      weekstart = 1, #start week on monday
      language = "en",
      width = NULL,
      autoclose = TRUE,
      datesdisabled = NULL,
      daysofweekdisabled = NULL
    ),
    
    #select hike type
    selectInput(
      inputId = "hiketype",
      label = "What type of hike is it?",
      choices = list(
        "regular" = "regular",
        "city trip" = "city_trip",
        "night hike" = "night_hike",
        "heavy hike" = "heavy_hike",
        "special nature" = "special_nature",
        "other special" = "other_special",
        "game" = "game"
      ),
      selected = NULL,
      multiple = FALSE,
      selectize = TRUE,
      width = NULL,
      size = NULL
    ),
    
    #starting time input
    sliderInput(
      inputId = "start_time",
      label = "Starting Time of Hike",
      min = as.POSIXct("7:30", format="%H:%M", tz="UTC"),
      max = as.POSIXct("12:30", format="%H:%M", tz="UTC"),
      value = as.POSIXct("10:30", format="%H:%M", tz="UTC"),
      step = 1800,
      timeFormat = "%H:%M",
      timezone = "+0000"
    ),
    
    #rain
    checkboxInput(inputId = "rain", label = "Will there be rain?", value = FALSE, width = NULL),
    
    #submit inputs
    submitButton(text = "Tell me the future great oracle...!", icon = icon("person-hiking"), width = NULL)
  ),
  # Output: Histogram
  plotOutput(outputId = "distPlot")
)

# levels(as.factor(dat$special_category)) check what number id the different hike types get in the model

# Define server logic required to draw a histogram ----

server <- function(input, output) {
  
  #draw the posterior predictive distribution ----
  output$distPlot <- renderPlot({
    
    #figure out what type of hike it is from user input ----
    typeid <- switch(input$hiketype,
                     city_trip = 1,
                     game = 2,
                     heavy_hike = 3,
                     night_hike = 4,
                     other_special = 5,
                     regular = 6,
                     special_nature = 7,
                     'hike type is invalid')
    
    #check if type of hike is not a night hike
    morning_start <- ifelse(typeid == 4, 0, 1)
    
    #extract start time in minutes from midnight and convert to standardized time
    hours <- as.integer(format(input$start_time, format="%H"))
    minutes <- as.integer(format(input$start_time, format="%M"))
    total_minutes <- hours*60 + minutes
    start_time_std <- (total_minutes - 672)/83 #hardcoded based on mean and sd calculated in data_preparation.R
    
    #check if year given is 2022
    is_2022 <- format(input$date, format="%Y") == "2022"
    
    #check if the month is in winter
    month <- as.integer(format(input$date, format="%m"))
    is_winter <- switch( month, 1,1,0,0,0,0,0,0,0,0,1,1)
    
    #check if day of the hike is a sunday
    is_sunday <- weekdays(input$date) == "Sunday"
    
    #check if raining
    rain <- as.integer(input$rain)
    
    #gather all user input plus defaults into a list
    d <- list(
      typeid = typeid,
      rain = rain,
      is_sunday = is_sunday,
      is_winter = is_winter,
      is_2022 = is_2022,
      start_time = start_time_std,
      morning_start = morning_start,
      last_hike = 0 #assume the last hike happened 1 week ago
    )
    
    #compute model predictions
    
    #marginalize across posterior parameter estimates
    linear_predictor <- post$a[,d$typeid] + post$r*d$rain + post$y*d$is_2022 + post$w*d$is_winter + post$es*d$morning_start*d$start_time + post$dow*d$is_sunday + post$wlh*d$last_hike
    simulated_signups <- rnbinom(n=length(linear_predictor), mu=exp(linear_predictor), size=post$phi)
    
    qq <- quantile(simulated_signups, probs=c(0.055,0.5,0.945))
    qq0 <- quantile(simulated_signups, probs=c(0.25,0.75))
    
    #calculate optimal number of breaks using friedman-diaconis method
    optimal_breaks <- (max(simulated_signups) - min(simulated_signups))/(2*(qq0[2] - qq0[1])*length(linear_predictor)^(-0.33))
    
    #determine best axis scale
    upper.xaxis <-  ifelse(typeid == 7, 200, 70)

    hist(simulated_signups, breaks = optimal_breaks, col = "#EB6864", border = "orange",
         xlab = "Hike Signups",
         ylab = "",
         main = paste0("Median Predicted Hike Signups: ", round(qq[2]), " (89% PI: ", round(qq[1]), " - ", round(qq[3]), ")"),
         xlim=c(0, upper.xaxis),
         xaxt= "n",
         yaxt="n")
    axis(1, at= seq(0, upper.xaxis, by=5))
    abline(v=qq[1], lty=2)
    abline(v=qq[2], lty=3, lwd=5, col='#FCB9B8')
    abline(v=qq[3], lty=2)
  })
  
}

#execute ----
shinyApp(ui = ui, server = server)




