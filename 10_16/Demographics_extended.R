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
  rename(total_pop=total)

# Change names for states in demographic database
demographics$state <- state.name[match(demographics$state, state.abb)]

# Create a merged dataset
poll_pvstate_df <- pvstate_df %>%
  inner_join(
    pollstate_df %>% 
      filter(weeks_left > 5, weeks_left < 10) 
  ) %>%
  left_join(vep_df) %>%
  left_join(demographics, by = c("state", "year")) %>%
  filter(year > 1989)


#####------------------------------------------------------#
##### Create histograms ####
#####------------------------------------------------------#

# Create empty lists/data.frames to store output
state_forecast <- list()
VEP <- list()

# Load in 2020 polls
polls_2020 <- read.csv("polls_2020.csv") %>%
  filter(answer %in% c("Biden", "Trump")) %>% 
  filter(!grepl("19$", start_date)) %>% 
  mutate(start_date = as.Date(start_date, "%m/%d/%y")) %>% 
  filter(start_date >= as.Date.character("2020-06-01")) %>% 
  group_by(answer, state) %>% 
  summarise(avg_poll = mean(pct))

# Remove special districts and states that cause issues in the model
states <- polls_2020 %>% 
  filter(!state %in% c("", "Nebraska CD-1", "Nebraska CD-2", "Maine CD-1", "Maine CD-2")) 
state_list <- unique(states$state)
state_means <- as.data.frame(state_list) %>%
  add_column(r_vote = NA, d_vote = NA)

# Generate results for each state
for (s in state_list) {
  
  # Past Democratic voting data for given state
  state_forecast[[s]]$dat_D <- poll_pvstate_df %>% 
    filter(state == s, party == "democrat") 
  
  # Apply a binomial model to estimate accuracy of polls on Democratic election outcome
  state_forecast[[s]]$mod_D <- glm(cbind(D, VEP-D) ~ avg_poll + Female + Black + Asian + Hispanic + Indigenous, 
                                   state_forecast[[s]]$dat_D, family = binomial)
  
  # Generate standard error for Democratic candidates
  state_forecast[[s]]$std_error_dem <- round(coef(summary(state_forecast[[s]]$mod_D))[, "Std. Error"], digits = 3)
  
  # Past Republican voting data for given state
  state_forecast[[s]]$dat_R <- poll_pvstate_df %>% 
    filter(state == s, party == "republican")  
  
  # Apply a binomial model to estimate accuracy of polls on Republican election outcome
  state_forecast[[s]]$mod_R <- glm(cbind(R, VEP-R) ~ avg_poll + Female + Black + Asian + Hispanic + Indigenous, 
                                   state_forecast[[s]]$dat_R, family = binomial)

  # Generate standard error for Republican candidates
  state_forecast[[s]]$std_error_rep <- coef(summary(state_forecast[[s]]$mod_R))[, "Std. Error"]

  
  # Polling averages for Biden from given state
  biden_raw_vote <- polls_2020 %>%
    filter(state == s, answer == "Biden")
  
  # Polling averages for Trump from given state
  trump_raw_vote <- polls_2020 %>%
    filter(state == s, answer == "Trump")
  
  # Approximate 2020 demographics with 2018 stats
  demograph_2018 <- demographics %>%
    filter(year == "2018", state == `s`)

  # Feed in latest polling data to predict Biden/Trump votes in given state
  state_forecast[[s]]$prob_Rvote <- predict(state_forecast[[s]]$mod_R, newdata = data.frame(avg_poll=trump_raw_vote[[3]], Female=demograph_2018$Female[[1]], Asian=demograph_2018$Asian[[1]], Black=demograph_2018$Black[[1]], Hispanic=demograph_2018$Hispanic[[1]], Indigenous=demograph_2018$Indigenous[[1]]), se=T, type="response")
  state_forecast[[s]]$prob_Dvote <- predict(state_forecast[[s]]$mod_D, newdata = data.frame(avg_poll=biden_raw_vote[[3]], Female=demograph_2018$Female[[1]], Asian=demograph_2018$Asian[[1]], Black=demograph_2018$Black[[1]], Hispanic=demograph_2018$Hispanic[[1]], Indigenous=demograph_2018$Indigenous[[1]]), se=T, type="response")

  # Get Voting eligible population for given state
  VEP[[s]] <- as.integer(vep_df$VEP[vep_df$state == s & vep_df$year == 2016])
  
  # Generate 10000 simulations
  state_forecast[[s]]$sim_Rvotes <- rbinom(n = 10000, size = VEP[[s]], prob = rnorm(10000, mean=state_forecast[[s]]$prob_Rvote[[1]], sd=state_forecast[[s]]$std_error_rep[[2]]))
  state_forecast[[s]]$sim_Dvotes <- rbinom(n = 10000, size = VEP[[s]], prob = rnorm(10000, mean=state_forecast[[s]]$prob_Dvote[[1]], sd=state_forecast[[s]]$std_error_dem[[2]]))
  
  # Generate candidate mean vote share
  state_means[`s` == state_list, "r_vote"] <- mean(state_forecast[[s]]$sim_Rvotes, na.rm=TRUE)
  state_means[`s` == state_list, "d_vote"] <- mean(state_forecast[[s]]$sim_Dvotes, na.rm=TRUE)
 
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

# Record winner of each state
state_means <- state_means %>%
  mutate(margin = (r_vote - d_vote)/(r_vote + d_vote)) %>%
  mutate("state" = state_list, "value" = margin) %>%
  mutate(value2 = ifelse(r_vote > d_vote,"Republican","Democrat"))


plot_usmap(data = state_means, regions = "states", values = "value") +
  scale_fill_gradient(low = "blue", high = "red", name = "state PV winner") +
  theme_void()

plot_usmap(data = state_means, regions = "states", values = "value2") +
  scale_fill_manual(values = c("blue", "red"), name = "state PV winner") +
  theme_void()

