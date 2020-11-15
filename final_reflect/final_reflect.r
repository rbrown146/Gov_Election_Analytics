library(tidyverse)
library(ggplot2)
library(usmap)
library(googlesheets4)

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
      summarise(avg_poll = mean(avg_poll))
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
  summarise(r_vote=sum(r_vote), d_vote=sum(d_vote), r_sd=sum(r_sd), d_sd=sum(d_sd))

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

### Generate graphics of actual results

# Read in Actual results
sheets_deauth()
new_data <- read_sheet("https://docs.google.com/spreadsheets/d/1faxciehjNpYFNivz-Kiu5wGl32ulPJhdJTDsULlza5E/edit#gid=0") %>%
  tail(-1) %>%
  select(state = `Geographic Name`, biden = `Joseph R. Biden Jr.`, trump = `Donald J. Trump`) %>%
  mutate(trump = as.numeric(trump), biden = as.numeric(biden), tpvp=trump+biden, margin_actual=(trump-biden)/tpvp) %>%
  left_join(state_means, by = "state") %>%
  mutate(act_win = ifelse(trump > biden,"Republican","Democrat"), miss=abs(margin - margin_actual))

# Create Table for Plotting
error_table <- new_data %>%
  select(miss, state_list, act_win)

# Bar plot of size of win margin prediction errors
ggplot(error_table, aes(reorder(state_list, miss), fill=act_win)) + 
  geom_bar(aes(weight=miss)) + geom_text(aes(label=paste0(round(100*miss,2), "%"), y=miss, hjust=-0.25)) + 
  coord_flip() + 
  guides(fill=FALSE) + 
  scale_y_continuous(breaks = seq(0, 0.6, 1), limits = c(0, 0.6)) +
  labs(y="Percentage Points Off", x = "State", title = "Win Margin Prediction Error") +
  scale_fill_manual(values = c("Republican"="red", "Democrat"="blue"))

# Difference between predicted and actual win margin
ggplot(new_data, aes(x = margin*100, y = reorder(state, margin), color = margin)) +
  geom_point() +
  geom_errorbar(aes(xmin = margin_actual*100, xmax = margin*100)) +
  scale_color_gradientn(colors=c("blue", "blue", "purple", "red", "red"),
                        values = c(0, .48, .55, .7, 1)) +
  theme_minimal() +
  theme(axis.text.y = element_text(size = 7),
        legend.position = "none") +
  ylab("") +
  xlab("Predicted/Actual Win Margin %") +
  geom_vline(xintercept = 0, lty = 2) +
  labs(title = "Win Margin for Biden and Trump",
       subtitle = "Model Prediction (Dot) and Actual Outcome (Bar)")

# Difference between predicted and actual number of votes for Trump
ggplot(new_data, aes(x = trump, y = reorder(state, margin))) +
  geom_point(color="red") +
  geom_errorbar(aes(xmin = r_vote-1.96*(r_sd), xmax = r_vote+1.96*(r_sd))) +
  scale_alpha_manual() +
  theme_minimal() +
  theme(axis.text.y = element_text(size = 7),
        legend.position = "none") +
  ylab("") +
  xlab("Number of Votes") +
  geom_vline(xintercept = 0, lty = 2) +
  labs(title = "Votes for Trump",
       subtitle = "Actual Outcome (Dot) and Model 95% CI (Bars)")

# Difference between predicted and actual number of votes for Biden
ggplot(new_data, aes(x = biden, y = reorder(state, margin))) +
  geom_point(color="blue") +
  geom_errorbar(aes(xmin = d_vote-1.96*(d_sd), xmax = d_vote+1.96*(d_sd))) +
  theme_minimal() +
  theme(axis.text.y = element_text(size = 7),
        legend.position = "none") +
  ylab("") +
  xlab("Number of Votes") +
  geom_vline(xintercept = 0, lty = 2) +
  labs(title = "Votes for Biden",
       subtitle = "Actual Outcome (Dot) and Model 95% CI (Bars)")

# Actual Map of Outcomes
plot_usmap(data = new_data, regions = "states", values = "act_win") +
  scale_fill_manual(values = c("blue", "red"), name = "Actual State PV Winner 2020") +
  theme_void()
