library(tidyverse)
library(ggplot2)

#####------------------------------------------------------#
##### Read and merge data ####
#####------------------------------------------------------#

# Load in data
pvstate_df    <- read_csv("popvote_bystate_1948-2016.csv")
economy_df    <- read_csv("econ.csv")
pollstate_df  <- read_csv("pollavg_bystate_1968-2016.csv")
vep_df <- read_csv("vep_1980-2016.csv")

# Create a merged dataset
poll_pvstate_df <- pvstate_df %>%
  inner_join(
    pollstate_df %>% 
      filter(weeks_left == 5) 
  ) %>%
  left_join(vep_df)

#####------------------------------------------------------#
##### Create histograms ####
#####------------------------------------------------------#

# Create empty lists/data.frames to store output
state_forecast <- list()
state_forecast_outputs <- data.frame()
VEP <- list()

# Load in 2020 polls
polls_2020 <- read.csv("polls_2020.csv") %>%
  filter(answer %in% c("Biden", "Trump")) %>% 
  filter(!grepl("19$", start_date)) %>% 
  mutate(start_date = as.Date(start_date, "%m/%d/%y")) %>% 
  filter(start_date >= as.Date.character("2020-06-01")) %>% 
  group_by(answer, state) %>% 
  summarize(avg_poll = mean(pct), .groups = "drop_last")

# Remove special districts and states that cause issues in the model
states <- polls_2020 %>% 
  filter(!state %in% c("", "Nebraska CD-1", "Nebraska CD-2", "Maine CD-1", "Maine CD-2", "Vermont")) 
state_list <- unique(states$state)

# Generate results for each state
for (s in state_list) {
  
  # Past Democratic voting data for given state
  state_forecast[[s]]$dat_D <- poll_pvstate_df %>% 
    filter(state == s, party == "democrat") 

  # Apply a binomial model to estimate accuracy of polls on Democratic election outcome
  state_forecast[[s]]$mod_D <- glm(cbind(D, VEP-D) ~ avg_poll, 
                                  state_forecast[[s]]$dat_D, family = binomial)
 
  # Past Republican voting data for given state
  state_forecast[[s]]$dat_R <- poll_pvstate_df %>% 
    filter(state == s, party == "republican")  
  
  # Apply a binomial model to estimate accuracy of polls on Republican election outcome
  state_forecast[[s]]$mod_R <- glm(cbind(R, VEP-R) ~ avg_poll, 
                                  state_forecast[[s]]$dat_R, family = binomial)
 # Polling averages for Biden from given state
  biden_raw_vote <- polls_2020 %>%
    filter(state == s, answer == "Biden")
  
  # Polling averages for Trump from given state
  trump_raw_vote <- polls_2020 %>%
    filter(state == s, answer == "Trump")

  # Feed in latest polling data to predict Biden/Trump votes in given state
  state_forecast[[s]]$prob_Rvote <- predict(state_forecast[[s]]$mod_R, newdata = data.frame(avg_poll=trump_raw_vote[[3]]), type="response")[[1]]
  state_forecast[[s]]$prob_Dvote <- predict(state_forecast[[s]]$mod_D, newdata = data.frame(avg_poll=biden_raw_vote[[3]]), type="response")[[1]]
  
  # Get Voting eligible population for given state
  VEP[[s]] <- as.integer(vep_df$VEP[vep_df$state == s & vep_df$year == 2016])

  # Generate 10000 simulations
  state_forecast[[s]]$sim_Rvotes <- rbinom(n = 10000, size = VEP[[s]], prob = state_forecast[[s]]$prob_Rvote)
  state_forecast[[s]]$sim_Dvotes <- rbinom(n = 10000, size = VEP[[s]], prob = state_forecast[[s]]$prob_Dvote)
  
  # Biden histograms
  jpeg(paste("hist_", s, "_Biden.jpg", sep = ""))
  hist(state_forecast[[s]]$sim_Dvotes, 
       xlab="predicted turnout draws for Biden\nfrom 10,000 binomial process simulations", 
       main = paste("Simulated Votes for Biden in ", s, sep=""),
       col = "blue",
       breaks=100)
  dev.off()
  
  # Trump histograms
  jpeg(paste("hist_", s, "_Trump.jpg", sep = ""))
  hist(state_forecast[[s]]$sim_Rvotes, 
       xlab="predicted turnout draws for Trump\nfrom 10,000 binomial process simulations",
       main = paste("Simulated Votes for Trump in ", s, sep=""),
       col = "red",
       breaks=100)
  dev.off()
}
