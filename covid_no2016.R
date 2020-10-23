library(tidyverse)
library(usmap)


#####------------------------------------------------------#
##### Read and merge data ####
#####------------------------------------------------------#

# Load in data
covid <- read_csv("United_States_COVID-19_Cases_and_Deaths_by_State_over_Time.csv")

county_demograph <- read_csv("demog_county_1990-2018.csv")
popvote_county <- read_csv("popvote_bycounty_2000-2016.csv")

demographics <- read_csv("demographic_1990-2018.csv") %>%
  rename(total_pop=total) %>%
  filter(year == 2018)

# Merge datasets
covid <- covid %>%
  left_join(demographics, by="state") %>%
  mutate(covid_pct = 100*tot_cases/total_pop, covid_death_pct = 100*tot_death/total_pop)

# Change state names to be in line with other databases
covid$state <- state.name[match(covid$state, state.abb)]

# --------------------- Create Map of Covid Cases ------------------------------------

# Create database of cases on September 1
grand_df <- covid %>%
  filter(submission_date == "09/01/2020") 
   
# Create database of cases on October 21
grand_df_2 <- covid %>%
  filter(submission_date == "10/21/2020") 

# Map of cases on September 1
plot_usmap(data = grand_df, regions = "states", values = "covid_pct") +
  scale_fill_gradient(low = "white", high = "red", name = "Percent") +
  labs(title="Total Covid Cases as Percent of Population", subtitle= "September 1") +
  theme_void()

# Map of cases on October 21
plot_usmap(data = grand_df_2, regions = "states", values = "covid_pct") +
  scale_fill_gradient(low = "white", high = "red", name = "Percent") +
  labs(title="Total Covid Cases as Percent of Population", subtitle= "October 21") +
  theme_void()

# Map of deaths on September 1
plot_usmap(data = grand_df, regions = "states", values = "covid_death_pct") +
  scale_fill_gradient(low = "white", high = "red", name = "Percent") +
  labs(title="Total Covid Deaths as Percent of Population", subtitle= "September 1") +
  theme_void()

# Map of deaths on October 21
plot_usmap(data = grand_df_2, regions = "states", values = "covid_death_pct") +
  scale_fill_gradient(low = "white", high = "red", name = "Percent") +
  labs(title="Total Covid Deaths as Percent of Population", subtitle= "October 21") +
  theme_void()

# -------------------------------- Create Predictive Model --------------------------------------
# Load in data
pvstate_df    <- read_csv("popvote_bystate_1948-2016.csv")
economy_df    <- read_csv("econ.csv")
pollstate_df  <- read_csv("pollavg_bystate_1968-2016.csv")
vep_df <- read_csv("vep_1980-2016.csv")
demographics <- read_csv("demographic_1990-2018.csv") %>%
  rename(total_pop=total)

# Change names for states in demographic database
demographics$state <- state.name[match(demographics$state, state.abb)]

# Gather Covid cases by state on September 1
covid_simple <- covid %>% 
  filter(submission_date == "09/01/2020") %>%
  select(state, covid_pct, covid_death_pct) 

# Get 2016 election results
pvstate_df <- pvstate_df %>%
  filter(year == 2016)

# Create empty lists/data.frames to store output
state_forecast <- list()
VEP <- list()

# Load in 2020 polls from between June and September
polls_2020 <- read.csv("polls_2020.csv") %>%
  filter(answer %in% c("Biden", "Trump")) %>% 
  filter(!grepl("19$", start_date)) %>% 
  mutate(start_date = as.Date(start_date, "%m/%d/%y")) %>% 
  filter(start_date >= as.Date.character("2020-06-01"), start_date < as.Date.character("2020-09-01")) %>% 
  group_by(answer, state) %>% 
  summarise(avg_poll = mean(pct)) %>%
  left_join(covid_simple, by="state") %>%
  left_join(pvstate_df %>% select(state, R_pv2p, D_pv2p), by="state")

# Remove special districts and states that cause issues in the model
states <- polls_2020 %>% 
  filter(!state %in% c("", "Nebraska CD-1", "Nebraska CD-2", "Maine CD-1", "Maine CD-2")) 
state_list <- unique(states$state)
state_means <- as.data.frame(state_list) %>%
  add_column(r_vote = NA, d_vote = NA)

# Generate results for each state
for (s in state_list) {
  
  # Polling averages for Biden from given state
  biden_raw_vote_old <- polls_2020 %>%
    filter(state == `s`, answer == "Biden") 

  # Polling averages for Trump from given state
  trump_raw_vote_old <- polls_2020 %>%
    filter(state == `s`, answer == "Trump")
  
  # Apply a binomial model to estimate impact of covid on Democratic polling outcome
  state_forecast[[s]]$mod_D <- glm(cbind(avg_poll, 100-avg_poll) ~ covid_pct, 
                                   biden_raw_vote_old, family = binomial)

  # Generate standard error for Democratic candidates
  state_forecast[[s]]$std_error_dem <- round(coef(summary(state_forecast[[s]]$mod_D))[, "Std. Error"], digits = 3)

  # Apply a binomial model to estimate impact of covid on Republican polling outcome
  state_forecast[[s]]$mod_R <- glm(cbind(avg_poll, 100-avg_poll) ~ covid_pct, 
                                   trump_raw_vote_old, family = binomial)
  
  # Generate standard error for Republican candidates
  state_forecast[[s]]$std_error_rep <- coef(summary(state_forecast[[s]]$mod_R))[, "Std. Error"]

  # Generate number of Covid cases on October 21
  covid_polls <- covid %>%
    filter(submission_date == "10/21/2020") %>%
    select(state, covid_pct, covid_death_pct) %>%
    filter(state == `s`) 

  # Feed in latest polling data to predict Biden/Trump votes in given state
  state_forecast[[s]]$prob_Rvote <- predict(state_forecast[[s]]$mod_R, newdata = data.frame(covid_pct=covid_polls$covid_pct[[1]]), se=T, type="response")
  state_forecast[[s]]$prob_Dvote <- predict(state_forecast[[s]]$mod_D, newdata = data.frame(covid_pct=covid_polls$covid_pct[[1]]), se=T, type="response")

  # Generate 10000 simulations
  state_forecast[[s]]$sim_Rvotes <- rbinom(n = 10000, size = 10000, prob = rnorm(10000, mean=state_forecast[[s]]$prob_Rvote[[1]], sd=state_forecast[[s]]$std_error_rep[[1]]))
  state_forecast[[s]]$sim_Dvotes <- rbinom(n = 10000, size = 10000, prob = rnorm(10000, mean=state_forecast[[s]]$prob_Dvote[[1]], sd=state_forecast[[s]]$std_error_dem[[1]]))

  # Generate candidate mean vote share
  state_means[`s` == state_list, "r_vote"] <- mean(state_forecast[[s]]$sim_Rvotes, na.rm=TRUE)
  state_means[`s` == state_list, "d_vote"] <- mean(state_forecast[[s]]$sim_Dvotes, na.rm=TRUE)
}

# Record winner of each state
state_means <- state_means %>%
  mutate(margin = (r_vote - d_vote)/(r_vote + d_vote)) %>%
  mutate("state" = state_list, "value" = margin) %>%
  mutate(value2 = ifelse(r_vote > d_vote,"Republican","Democrat"))

# Plot map of state winner
plot_usmap(data = state_means, regions = "states", values = "value2") +
  scale_fill_manual(values = c("blue", "red"), name = "state PV winner") +
  labs(title = "State Winner Based on Covid Data, No 2016 Data") +
  theme(legend.position = "right")

ggsave("covid_no_2016.jpg")
