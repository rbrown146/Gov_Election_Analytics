library(tidyverse)
library(ggplot2)
library(usmap)


#####------------------------------------------------------#
##### Read and merge data ####
#####------------------------------------------------------#

# Load in data
pvstate_df    <- read_csv("popvote_bystate_1948-2016.csv")
economy_df    <- read_csv("econ.csv")
pollstate_df  <- read_csv("pollavg_bystate_1968-2016.csv")
vep_df <- read_csv("vep_1980-2016.csv")
demographics <- read_csv("demographic_1990-2018.csv") %>%
  rename(total_pop=total) %>%
  group_by(state) %>% 
  mutate(chg_Female = ifelse(year != 1992, Female - lag(Female, n=4), Female - lag(Female, n=2)),
         chg_Black = ifelse(year != 1992, Black - lag(Black, n=4), Black - lag(Black, n=2)),
         chg_Asian = ifelse(year != 1992, Asian - lag(Asian, n=4), Asian - lag(Asian, n=2)),
         chg_Hispanic = ifelse(year != 1992, Hispanic - lag(Hispanic, n=4), Hispanic - lag(Hispanic, n=2)),
         chg_White = ifelse(year != 1992, White - lag(White, n=4), White - lag(White, n=2)),
         chg_Indigenous = ifelse(year != 1992, Indigenous - lag(Indigenous, n=4), Indigenous - lag(Indigenous, n=2)),
         chg_20 = ifelse(year != 1992, age20 - lag(age20, n=4), age20 - lag(age20, n=2)),
         chg_3045 = ifelse(year != 1992, age3045 - lag(age3045, n=4), age3045 - lag(age3045, n=2)),
         chg_65 = ifelse(year != 1992, age65 - lag(age65, n=4), age65 - lag(age65, n=2))
         ) %>%
  ungroup()

# Change names for states in demographic database
demographics$state <- state.name[match(demographics$state, state.abb)]

demographics$state <- replace_na(demographics$state, "District of Columbia") 

# Create a merged dataset
poll_pvstate_df <- pvstate_df %>%
  inner_join(
    pollstate_df %>% 
      filter(weeks_left > 5, weeks_left < 24) %>%
      group_by(year, party, state) %>%
      summarize(avg_poll = mean(avg_poll))
  ) %>%
  left_join(vep_df) %>%
  left_join(demographics, by = c("state", "year")) %>%
  filter(year > 1989) %>%
  mutate(region = ifelse(
    state %in% c("Alabama", "Mississippi", "Tennessee", "Arkansas", "Louisiana", "Oklahoma", "Kentucky", "West Virginia"), "Core_South",
    ifelse(state %in% c("Florida", "Georgia", "Texas", "North Carolina", "South Carolina", "Arizona", "New Mexico", "Nevada"), "Sun_Belt",
    ifelse(state %in% c("Virginia", "Maryland", "Delaware", "New Jersey", "New York", "Connecticut", "Rhode Island", "Vermont", "Maine", "District of Columbia", "Massachusetts"), "North_East",
    ifelse(state %in% c("New Hampshire", "Pennsylvania", "Ohio", "Michigan", "Wisconsin", "Minnesota", "Iowa"), "Midwest_Swing",
    ifelse(state %in% c("Indiana", "Kansas", "Nebraska", "South Dakota", "North Dakota", "Illinois", "Missouri"), "Midwest_Stable",
    ifelse(state %in% c("Colorado","Montana", "Idaho", "Wyoming", "Alaska", "Utah"), "Rocky_Mountain",
    ifelse(state %in% c("Hawaii", "Washington", "Oregon", "California"), "West_Coast", "error"
    )))))))
  )

# I put New Hampshire with the Midwestern swing states because it seemed like a
# better fit than putting it with the Northeastern states

#####------------------------------------------------------#
##### Create dataframes and lists for later use ####
#####------------------------------------------------------#

# Create empty lists/data.frames to store output
state_forecast <- list()
VEP <- list()

# Load in 2020 polls
polls_2020 <- read.csv("polls_2020.csv") %>%
  filter(answer %in% c("Biden", "Trump")) %>% 
  filter(!grepl("19$", start_date)) %>% 
  mutate(start_date = as.Date(start_date, "%m/%d/%y")) %>% 
  filter(start_date >= as.Date.character("2020-04-01")) %>% 
  group_by(answer, state) %>% 
  summarise(avg_poll = mean(pct)) %>%
  ungroup()

# Load in 2016 polls
polls_2016 <- read.csv("polls_2016.csv") %>%
  filter(!grepl("15$", startdate)) %>% 
  mutate(startdate = as.Date(startdate, "%m/%d/%Y")) %>% 
  filter(startdate >= as.Date.character("2016-06-01")) %>% 
  filter(startdate < as.Date.character("2016-09-20")) %>%
  group_by(state) %>% 
  summarise(rawpoll_clinton = mean(rawpoll_clinton), rawpoll_trump = mean(rawpoll_trump))

# Remove special districts and states that cause issues in the model
states <- polls_2020 %>% 
  filter(!state %in% c("", "Nebraska CD-1", "Nebraska CD-2", "Maine CD-1", "Maine CD-2")) 
state_list <- unique(states$state)


#####------------------------------------------------------#
##### Adding in missing polling data ####
#####------------------------------------------------------#

# Create a place to store results
missing <- list()

# Gather names of states with no late-stage 2020 polling data
missing_states <- c("District of Columbia", "Wyoming", "North Dakota", "South Dakota", "Nebraska", "Illinois", "West Virginia", "Rhode Island")

# Create df of Biden polls
polls_d_2020 <- polls_2020 %>%
  filter(answer == "Biden", !state %in% c("", "Maine CD-1", "Maine CD-2", "Nebraska CD-1", "Nebraska CD-2")) 

# Create df of Trump polls
polls_r_2020 <- polls_2020 %>%
  filter(answer == "Trump", !state %in% c("", "Maine CD-1", "Maine CD-2", "Nebraska CD-1", "Nebraska CD-2"))

for(s in missing_states){
  
  # Create dataframe of past Democratic polls
  s_avg_d <- poll_pvstate_df %>%
    filter(state == s, party == "democrat") %>% 
    select(year, s_poll_d = avg_poll, party) 
  
  # Create dataframe of past Republican polls
  s_avg_r <- poll_pvstate_df %>%
    filter(state == s, party == "republican") %>% 
    select(year, s_poll_r = avg_poll, party) 
  
  # Remove Democratic results for states with no 2020 polling data
  poll_missing_d <- poll_pvstate_df %>%
    left_join(s_avg_d, by = c("year", "party"), copy=TRUE) %>%
    filter(state != s, party == "democrat") %>%
    filter(state %in% state_list)
  
  # Remove Republican results for states with no 2020 polling data 
  poll_missing_r <- poll_pvstate_df %>%
    left_join(s_avg_r, by = c("year", "party"), copy=TRUE) %>%
    filter(state != s, party == "republican") %>%
    filter(state %in% state_list) 
  
  # Create model to predict how Biden would poll in missing states
  d_poll <- glm(cbind(s_poll_d, 100-s_poll_d) ~ avg_poll*state, 
                poll_missing_d, family = binomial) 
  
  # Create model to predict how Trump would poll in missing states
  r_poll <- glm(cbind(s_poll_r, 100-s_poll_r) ~ avg_poll*state, 
                poll_missing_r, family = binomial) 
  
  # Predict polling data for missing states
  missing[[s]]$Rvote <- predict(r_poll, newdata=data.frame(avg_poll = polls_r_2020$avg_poll, state=polls_r_2020$state), se=T, type="response")
  missing[[s]]$Dvote <- predict(d_poll, newdata=data.frame(avg_poll = polls_d_2020$avg_poll, state=polls_d_2020$state), se=T, type="response")
  
  # Take average of results
  missing[[s]]$Rpoll <- sum(missing[[s]][["Rvote"]][["fit"]])/43
  missing[[s]]$Dpoll <- sum(missing[[s]][["Dvote"]][["fit"]])/43
  
  # Add polling values to polls_2020 df
  polls_2020 <- polls_2020 %>%
    add_row(answer="Biden", state=s, avg_poll = missing[[s]]$Dpoll) %>%
    add_row(answer="Trump", state=s, avg_poll = missing[[s]]$Rpoll)
}

# Prep data for inputting
states <- polls_2020 %>% 
  filter(!state %in% c("", "Nebraska CD-1", "Nebraska CD-2", "Maine CD-1", "Maine CD-2")) 
state_list <- unique(states$state)
state_means <- as.data.frame(state_list) %>%
  add_column(r_vote = NA, d_vote = NA)

#####------------------------------------------------------#
##### Create training data ####
#####------------------------------------------------------#

# Choose year to leave out
leaveout_yr <-2000

# Create Democratic training data
dem_train <- poll_pvstate_df %>%
  filter(party=="democrat") %>%
  filter(year != leaveout_yr)

# Create Democratic test data
dem_test <- poll_pvstate_df %>%
  filter(party=="democrat") %>%
  anti_join(dem_train, by = c("state", "year"))

# Create Republican trainiing data
rep_train <- poll_pvstate_df %>%
  filter(party=="republican") %>%
  filter(year != leaveout_yr)

# Create Republican test data
rep_test <- poll_pvstate_df %>%
  filter(party=="republican") %>%
  anti_join(dem_train, by = c("state", "year"))

#####------------------------------------------------------#
##### Model 1: Demographics ####
#####------------------------------------------------------#

# Create predictive model for Biden
big_model_d <- glm(cbind(D, VEP-D) ~ avg_poll + avg_poll*state + Black + Hispanic + Indigenous + Asian + age3045 + age20 + age65 + chg_3045*region + chg_Hispanic*region + chg_65*region + chg_20*region + chg_Black*region + chg_Asian*region + chg_Indigenous*region, 
                                 dem_train, family = binomial) 

# Create predictive model for Trump
big_model_r <- glm(cbind(R, VEP-R) ~ avg_poll + avg_poll*state + Black + Hispanic + Indigenous + Asian + age3045 + age20 + age65 + chg_3045*region + chg_Hispanic*region + chg_65*region + chg_20*region + chg_Black*region + chg_Asian*region + chg_Indigenous*region, 
                   rep_train, family = binomial) 

# Generate standard error for Democratic candidates
std_error_dem <- coef(summary(big_model_d))[, "Std. Error"]

# Generate standard error for Republican candidates
std_error_rep <- coef(summary(big_model_r))[, "Std. Error"]

# Generate results for each state
for (s in state_list) {
  
  # Polling averages for Biden from given state
  biden_raw_vote <- polls_2020 %>%
    filter(state == s, answer == "Biden")
  
  # Polling averages for Trump from given state
  trump_raw_vote <- polls_2020 %>%
    filter(state == s, answer == "Trump")
  
  # Approximate 2020 demographics with 2018 stats
  demograph_2018 <- demographics %>%
    filter(year == "2018", state == `s`)
  
  # Get each state's name
  region_df <- poll_pvstate_df %>%
    filter(state == `s`)

  # Feed in latest polling data to predict Biden/Trump votes in given state
  state_forecast[[s]]$new_prob_Rvote <- predict(big_model_r, newdata = data.frame(avg_poll=trump_raw_vote[[3]], chg_Female=demograph_2018$chg_Female[[1]], Asian=demograph_2018$Asian[[1]], chg_Asian=demograph_2018$chg_Asian[[1]], chg_Black=demograph_2018$chg_Black[[1]], chg_Indigenous=demograph_2018$chg_Indigenous[[1]], Black=demograph_2018$Black[[1]],  chg_Hispanic=demograph_2018$chg_Hispanic[[1]], Hispanic=demograph_2018$Hispanic[[1]], chg_White=demograph_2018$chg_White[[1]], White=demograph_2018$White[[1]], Indigenous=demograph_2018$Indigenous[[1]], chg_65=demograph_2018$chg_65[[1]], state=region_df$state[[1]], region=region_df$region[[1]], Female=demograph_2018$Female[[1]], chg_3045=demograph_2018$chg_3045[[1]], chg_20=demograph_2018$chg_20[[1]], age3045=demograph_2018$age3045[[1]],age4565=demograph_2018$age4565[[1]],age65=demograph_2018$age65[[1]],age20=demograph_2018$age20[[1]], incumbent_party="R", incumbent_candidate="yes"), se=T, type="response")
  state_forecast[[s]]$new_prob_Dvote <- predict(big_model_d, newdata = data.frame(avg_poll=biden_raw_vote[[3]], chg_Female=demograph_2018$chg_Female[[1]], Asian=demograph_2018$Asian[[1]], chg_Asian=demograph_2018$chg_Asian[[1]], chg_Black=demograph_2018$chg_Black[[1]], chg_Indigenous=demograph_2018$chg_Indigenous[[1]], Black=demograph_2018$Black[[1]], chg_Hispanic=demograph_2018$chg_Hispanic[[1]], Hispanic=demograph_2018$Hispanic[[1]], chg_White=demograph_2018$chg_White[[1]], White=demograph_2018$White[[1]], Indigenous=demograph_2018$Indigenous[[1]], chg_65=demograph_2018$chg_65[[1]], state=region_df$state[[1]], region=region_df$region[[1]], Female=demograph_2018$Female[[1]], chg_3045=demograph_2018$chg_3045[[1]], chg_20=demograph_2018$chg_20[[1]], age3045=demograph_2018$age3045[[1]],age4565=demograph_2018$age4565[[1]],age65=demograph_2018$age65[[1]],age20=demograph_2018$age20[[1]], incumbent_party="R", incumbent_candidate="yes"), se=T, type="response")

  # Get Voting eligible population for given state
  VEP[[s]] <- as.integer(vep_df$VEP[vep_df$state == s & vep_df$year == 2016])
  
  # Generate standard error for each state
  error_r <- ifelse(s != "Alabama", std_error_rep[[2]] + std_error_rep[[paste0("avg_poll:state",s)]], std_error_rep[[2]])
  error_d <- ifelse(s != "Alabama", std_error_dem[[2]] + std_error_dem[[paste0("avg_poll:state",s)]], std_error_dem[[2]])
  
  # Generate 10000 simulations
  state_forecast[[s]]$new_sim_Rvotes <- rbinom(n = 10000, size = VEP[[s]], prob = rnorm(10000, mean=state_forecast[[s]]$new_prob_Rvote[[1]], sd=error_r))
  state_forecast[[s]]$new_sim_Dvotes <- rbinom(n = 10000, size = VEP[[s]], prob = rnorm(10000, mean=state_forecast[[s]]$new_prob_Dvote[[1]], sd=error_d))
  
  # Generate candidate mean vote share
  state_means[`s` == state_list, "r_vote"] <- mean(state_forecast[[s]]$new_sim_Rvotes, na.rm=TRUE)
  state_means[`s` == state_list, "d_vote"] <- mean(state_forecast[[s]]$new_sim_Dvotes, na.rm=TRUE)
  state_means[`s` == state_list, "r_sd"] <- sd(state_forecast[[s]]$new_sim_Rvotes, na.rm=TRUE)
  state_means[`s` == state_list, "d_sd"] <- sd(state_forecast[[s]]$new_sim_Dvotes, na.rm=TRUE)
}

# Record winner of each state
state_means <- state_means %>%
  mutate(margin = (r_vote - d_vote)/(r_vote + d_vote)) %>%
  mutate("state" = state_list, "value" = margin) %>%
  mutate(value2 = ifelse(r_vote > d_vote,"Republican","Democrat"))

# Plot map of results
plot_usmap(data = state_means, regions = "states", values = "value2") +
  scale_fill_manual(values = c("blue", "red"), name = "State PV Winner, 2020 Prediction") +
  theme_void()

#####------------------------------------------------------#
##### Get national popular vote and confidence interval
#####------------------------------------------------------#

pop_vote <- state_means %>%
  summarize(r_vote=sum(r_vote), d_vote=sum(d_vote), r_sd=sum(r_sd), d_sd=sum(d_sd))

# Create Republican and Democratic variables
r <- pop_vote$r_vote
d <- pop_vote$d_vote

# Get Biden's national popular vote share
100*d/(r+d)

# Get Trump's national popular vote share
100*r/(r+d)

# Get Biden confidence interval
biden_ci <- c(d - 1.96*pop_vote$d_sd, d + 1.96*pop_vote$d_sd)
biden_ci

# Get Trump confidence interval
trump_ci <- c(r - 1.96*pop_vote$r_sd, r + 1.96*pop_vote$r_sd)
trump_ci

#####------------------------------------------------------#
##### Testing the model with test data (out-of-sample validation)
#####------------------------------------------------------#

# Generate results for each state
for (s in state_list) {
  
  # Get GOP results for state
  rep_small <- rep_test %>%
    filter(state == s)
  
  # Get Dem results for state
  dem_small <- dem_test %>%
    filter(state == s)
  
  # Feed in latest polling data to predict Biden/Trump votes in given state
  state_forecast[[s]]$new_prob_Rvote <- predict(big_model_r, newdata = data.frame(avg_poll=rep_small$avg_poll[[1]], chg_Female=rep_small$chg_Female[[1]], Asian=rep_small$Asian[[1]], chg_Asian=rep_small$chg_Asian[[1]], chg_Black=rep_small$chg_Black[[1]], chg_Indigenous=rep_small$chg_Indigenous[[1]], Black=rep_small$Black[[1]],  chg_Hispanic=rep_small$chg_Hispanic[[1]], Hispanic=rep_small$Hispanic[[1]], chg_White=rep_small$chg_White[[1]], White=rep_small$White[[1]], Indigenous=rep_small$Indigenous[[1]], chg_65=rep_small$chg_65[[1]], state=rep_small$state[[1]], region=rep_small$region[[1]], Female=rep_small$Female[[1]], chg_3045=rep_small$chg_3045[[1]], chg_20=rep_small$chg_20[[1]], age3045=rep_small$age3045[[1]],age4565=rep_small$age4565[[1]],age65=rep_small$age65[[1]],age20=rep_small$age20[[1]]), se=T, type="response")
  state_forecast[[s]]$new_prob_Dvote <- predict(big_model_d, newdata = data.frame(avg_poll=dem_small$avg_poll[[1]], chg_Female=dem_small$chg_Female[[1]], Asian=dem_small$Asian[[1]], chg_Asian=dem_small$chg_Asian[[1]], chg_Black=dem_small$chg_Black[[1]], chg_Indigenous=dem_small$chg_Indigenous[[1]], Black=dem_small$Black[[1]],  chg_Hispanic=dem_small$chg_Hispanic[[1]], Hispanic=dem_small$Hispanic[[1]], chg_White=dem_small$chg_White[[1]], White=dem_small$White[[1]], Indigenous=dem_small$Indigenous[[1]], chg_65=dem_small$chg_65[[1]], state=dem_small$state[[1]], region=dem_small$region[[1]], Female=dem_small$Female[[1]], chg_3045=dem_small$chg_3045[[1]], chg_20=dem_small$chg_20[[1]], age3045=dem_small$age3045[[1]],age4565=dem_small$age4565[[1]],age65=dem_small$age65[[1]],age20=dem_small$age20[[1]]), se=T, type="response")
  
  # Get Voting eligible population for given state
  VEP[[s]] <- as.integer(vep_df$VEP[vep_df$state == s & vep_df$year == 2000])
  
  # Generate standard error for each state
  error_r <- ifelse(s != "Alabama", std_error_rep[[2]] + std_error_rep[[paste0("avg_poll:state",s)]], std_error_rep[[2]])
  error_d <- ifelse(s != "Alabama", std_error_dem[[2]] + std_error_dem[[paste0("avg_poll:state",s)]], std_error_dem[[2]])
  
  # Generate 10000 simulations
  state_forecast[[s]]$new_sim_Rvotes <- rbinom(n = 10000, size = VEP[[s]], prob = rnorm(10000, mean=state_forecast[[s]]$new_prob_Rvote[[1]], sd=error_r))
  state_forecast[[s]]$new_sim_Dvotes <- rbinom(n = 10000, size = VEP[[s]], prob = rnorm(10000, mean=state_forecast[[s]]$new_prob_Dvote[[1]], sd=error_d))
  
  # Generate candidate mean vote share
  state_means[`s` == state_list, "r_vote_test"] <- mean(state_forecast[[s]]$new_sim_Rvotes, na.rm=TRUE)
  state_means[`s` == state_list, "d_vote_test"] <- mean(state_forecast[[s]]$new_sim_Dvotes, na.rm=TRUE)
  state_means[`s` == state_list, "r_sd_test"] <- sd(state_forecast[[s]]$new_sim_Rvotes, na.rm=TRUE)
  state_means[`s` == state_list, "d_sd_test"] <- sd(state_forecast[[s]]$new_sim_Dvotes, na.rm=TRUE)
}

# Record winner of each state
state_means <- state_means %>%
  mutate(margin_test = (r_vote_test - d_vote_test)/(r_vote_test + d_vote_test)) %>%
  mutate("state" = state_list, "value" = margin_test) %>%
  mutate(win_test = ifelse(r_vote_test > d_vote_test,"Republican","Democrat"))

# Plot map of results
plot_usmap(data = state_means, regions = "states", values = "win_test") +
  scale_fill_manual(values = c("blue", "red"), name = "State PV Winner, OOS Prediction (2000)") +
  theme_void()

### 2000 popular vote

# Get 2000 popular vote
pop_vote_2000 <- state_means %>%
  summarize(r_vote_test=sum(r_vote_test), d_vote_test=sum(d_vote_test), r_sd_test=sum(r_sd_test), d_sd_test=sum(d_sd_test))

# Create Republican and Democratic variables
r_00 <- pop_vote_2000$r_vote_test
d_00 <- pop_vote_2000$d_vote_test

# Get Gore's national popular vote share
100*d_00/(r_00+d_00)

# Get Bush's 2000 national popular vote share
100*r_00/(r_00+d_00)

# Get Gore confidence interval
gore_ci <- c(d_00 - 1.96*pop_vote_2000$d_sd_test, d_00 + 1.96*pop_vote_2000$d_sd_test)
gore_ci

# Get Bush confidence interval
bush_ci <- c(r_00 - 1.96*pop_vote_2000$r_sd_test, r_00 + 1.96*pop_vote_2000$r_sd_test)
bush_ci

#####------------------------------------------------------#
##### Testing the model with 2016 data (in-sample validation)
#####------------------------------------------------------#

# Create a place to store output
forecast_2016 <- list()

# Generate results for each state
for (s in state_list) {
  
  # Polling averages for Clinton and Trump from given state
  raw_2016 <- polls_2016 %>%
    filter(state == s)
  
  # Polling averages for Trump from given state
  trump_raw_2016 <- polls_2016 %>%
    filter(state == s)
  
  # Select 2016 demographic stats
  demograph_2016 <- demographics %>%
    filter(year == "2016", state == `s`)
  
  # Get each state's name
  region_df <- poll_pvstate_df %>%
    filter(state == `s`)
  
  # Feed in latest polling data to predict Clinton/Trump votes in given state
  forecast_2016[[s]]$new_prob_Rvote <- predict(big_model_r, newdata = data.frame(avg_poll=raw_2016$rawpoll_trump[[1]], Asian=demograph_2016$Asian[[1]], Black=demograph_2016$Black[[1]], Hispanic=demograph_2016$Hispanic[[1]], chg_Hispanic=demograph_2016$chg_Hispanic[[1]], chg_Female=demograph_2016$chg_Female[[1]], chg_Black=demograph_2016$chg_Black[[1]], chg_Asian=demograph_2016$chg_Asian[[1]], chg_Indigenous=demograph_2016$chg_Indigenous[[1]], White=demograph_2016$White[[1]],Indigenous=demograph_2016$Indigenous[[1]], state=region_df$state[[1]], region=region_df$region[[1]], Female=demograph_2016$Female[[1]], age3045=demograph_2016$age3045[[1]], age4565=demograph_2016$age4565[[1]], age20=demograph_2016$age20[[1]], age65=demograph_2016$age65[[1]], chg_3045=demograph_2016$chg_3045[[1]],chg_65=demograph_2016$chg_65[[1]],chg_20=demograph_2016$chg_20[[1]], incumbent_party="D", incumbent_candidate="no"), se=T, type="response")
  forecast_2016[[s]]$new_prob_Dvote <- predict(big_model_d, newdata = data.frame(avg_poll=raw_2016$rawpoll_clinton[[1]], Asian=demograph_2016$Asian[[1]], Black=demograph_2016$Black[[1]], Hispanic=demograph_2016$Hispanic[[1]], chg_Hispanic=demograph_2016$chg_Hispanic[[1]], chg_Female=demograph_2016$chg_Female[[1]], chg_Black=demograph_2016$chg_Black[[1]], chg_Asian=demograph_2016$chg_Asian[[1]], chg_Indigenous=demograph_2016$chg_Indigenous[[1]], White=demograph_2016$White[[1]], Indigenous=demograph_2016$Indigenous[[1]], state=region_df$state[[1]], region=region_df$region[[1]], Female=demograph_2016$Female[[1]], age3045=demograph_2016$age3045[[1]], age4565=demograph_2016$age4565[[1]], age20=demograph_2016$age20[[1]], age65=demograph_2016$age65[[1]], chg_3045=demograph_2016$chg_3045[[1]],chg_65=demograph_2016$chg_65[[1]],chg_20=demograph_2016$chg_20[[1]], incumbent_party="D", incumbent_candidate="no"), se=T, type="response")
  
  # Get Voting eligible population for given state
  VEP[[s]] <- as.integer(vep_df$VEP[vep_df$state == s & vep_df$year == 2016])
  
  # Generate standard error for each state
  error_r <- ifelse(s != "Alabama", std_error_rep[[2]] + std_error_rep[[paste0("avg_poll:state",s)]], std_error_rep[[2]])
  error_d <- ifelse(s != "Alabama", std_error_dem[[2]] + std_error_dem[[paste0("avg_poll:state",s)]], std_error_dem[[2]])
  
  # Generate 10000 simulations
  forecast_2016[[s]]$new_sim_Rvotes <- rbinom(n = 10000, size = VEP[[s]], prob = rnorm(10000, mean=forecast_2016[[s]]$new_prob_Rvote[[1]], sd=error_r))
  forecast_2016[[s]]$new_sim_Dvotes <- rbinom(n = 10000, size = VEP[[s]], prob = rnorm(10000, mean=forecast_2016[[s]]$new_prob_Dvote[[1]], sd=error_d))
  
  # Generate candidate mean vote share
  state_means[`s` == state_list, "r_vote_2016"] <- mean(forecast_2016[[s]]$new_sim_Rvotes, na.rm=TRUE)
  state_means[`s` == state_list, "d_vote_2016"] <- mean(forecast_2016[[s]]$new_sim_Dvotes, na.rm=TRUE)
  state_means[`s` == state_list, "r_sd_2016"] <- sd(forecast_2016[[s]]$new_sim_Rvotes, na.rm=TRUE)
  state_means[`s` == state_list, "d_sd_2016"] <- sd(forecast_2016[[s]]$new_sim_Dvotes, na.rm=TRUE)
}

# Record winner of each state
state_means <- state_means %>%
  mutate(margin_2016 = (r_vote_2016 - d_vote_2016)/(r_vote_2016 + d_vote_2016)) %>%
  mutate("state" = state_list, "value" = margin_2016) %>%
  mutate(winner_2016 = ifelse(r_vote_2016 > d_vote_2016,"Republican","Democrat"))

# Create map of results
plot_usmap(data = state_means, regions = "states", values = "winner_2016") +
  scale_fill_manual(values = c("blue", "red"), name = "State PV Winner, 2016 Prediction") +
  theme_void()

### 2016 popular vote

# Get 2016 popular vote
pop_vote_2016 <- state_means %>%
  summarize(r_vote_2016=sum(r_vote_2016), d_vote_2016=sum(d_vote_2016), r_sd_2016=sum(r_sd_2016), d_sd_2016=sum(d_sd_2016))

# Create Republican and Democratic variables
r_16 <- pop_vote_2016$r_vote
d_16 <- pop_vote_2016$d_vote

# Get Clinton's national popular vote share
100*d_16/(r_16+d_16)

# Get Trump's 2016 national popular vote share
100*r_16/(r_16+d_16)

# Get Clinton confidence interval
clinton_ci <- c(d_16 - 1.96*pop_vote_2016$d_sd_2016, d_16 + 1.96*pop_vote_2016$d_sd_2016)
clinton_ci

# Get Trump confidence interval
trump_16_ci <- c(r_16 - 1.96*pop_vote_2016$r_sd_2016, r_16 + 1.96*pop_vote_2016$r_sd_2016)
trump_16_ci
