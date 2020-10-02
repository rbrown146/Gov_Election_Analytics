#### Incumbency ####
#### Gov 1347: Election Analysis (2020)
#### TFs: Soubhik Barari, Sun Young Park
#### Assignment by Rick Brown

library(tidyverse)
library(usmap)

polls_2016 <- read_csv("polls_2020.csv")
polls_2020 <- read_csv("polls_2020.csv")
natl_popvote <- read_csv("popvote_1948-2016.csv")
state_polls <- read_csv("pollavg_bystate_1968-2016.csv")
state_results <- read_csv("popvote_bystate_1948-2016.csv")
local_econ <- read_csv("local.csv")

state_results <- state_results %>%
  select(-D, -R, -total) 

## NORTH CAROLINA

# Combine datasets and filter out irrelevant states
nc_data <- state_polls %>% 
  filter(state %in% c("North Carolina")) %>% 
  filter(weeks_left <= 20) %>% 
  left_join(state_results %>% filter(state == "North Carolina"), by = c("year", "state")) %>% 
  left_join(natl_popvote %>% select(-candidate, -pv, -pv2p, -winner, -prev_admin), by = c("year", "party")) %>%
  mutate(state_vote = ifelse(party == "republican", R_pv2p, D_pv2p)) %>%
  mutate(state_winner_party = ifelse(R_pv2p > D_pv2p, "republican", "democrat")) %>%
  mutate(state_winner = ifelse(state_winner_party == party, TRUE, FALSE)) %>%
  left_join(local_econ %>% filter(`State and area` == "North Carolina", Month == "04"), by = c("year" = "Year"))%>% 
  filter(!is.na(Unemployed_prce)) %>%
  mutate(id = row_number())

# Model 1

# Create training and test data
nc_train <- nc_data %>%
  sample_frac(0.60)
nc_test <- nc_data %>%
  anti_join(nc_train, by = "id")

# Create models
nc_incumbent <- lm(state_vote ~ avg_poll + Unemployed_prce + incumbent + incumbent_party + avg_poll*incumbent_party + avg_poll*incumbent + Unemployed_prce*incumbent_party + Unemployed_prce*incumbent, data = nc_train)

# Test model on test data
nc_mod_part <- nc_test %>% 
  mutate(prediction = predict(nc_incumbent, nc_test),
         pred_winner = case_when(
           prediction > 50 ~ TRUE,
           prediction < 50 ~ FALSE
         ),
         correct = pred_winner == state_winner) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Test model on entire dataset
nc_mod_whole <- nc_data %>% 
  mutate(prediction = predict(nc_incumbent, nc_data),
         pred_winner = case_when(
           prediction > 50 ~ TRUE,
           prediction < 50 ~ FALSE
         ),
         correct = pred_winner == state_winner) %>%  
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Model 2

# Create models
nc_incumbent_midterm <- lm(state_vote ~ avg_poll + Unemployed_prce + incumbent_party + avg_poll*incumbent_party + Unemployed_prce*incumbent_party, data = nc_train)

# Test model on test data
nc_mod_mid_part <- nc_test %>% 
  mutate(prediction = predict(nc_incumbent_midterm, nc_test),
         pred_winner = case_when(
           prediction > 50 ~ TRUE,
           prediction < 50 ~ FALSE
         ),
         correct = pred_winner == state_winner) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Test model on entire dataset
nc_mod_mid_whole <- nc_data %>% 
  mutate(prediction = predict(nc_incumbent_midterm, nc_data),
         pred_winner = case_when(
           prediction > 50 ~ TRUE,
           prediction < 50 ~ FALSE
         ),
         correct = pred_winner == state_winner) %>%  
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Find 2020 unemployment rate in North Carolina
unemp_2020_nc <- local_econ %>% 
  filter(Year == 2020, Month == "04", `State and area` == "North Carolina") %>% 
  select(Unemployed_prce) %>% 
  pull()

# Model 1 & 2's 2020 prediction
nc_2020 <- polls_2020 %>% 
  filter(state == "North Carolina") %>% 
  filter(answer %in% c("Biden", "Trump")) %>% 
  filter(!grepl("19$", start_date)) %>% 
  mutate(start_date = as.Date(start_date, "%m/%d/%y")) %>% 
  filter(start_date >= as.Date.character("2020-06-01")) %>% 
  group_by(answer) %>% 
  summarize(avg_poll = mean(pct), .groups = "drop_last") %>% 
  mutate(incumbent = c(FALSE, TRUE),
         incumbent_party = c(FALSE, TRUE),
         Unemployed_prce = unemp_2020_nc) 

# Model 1 prediction
nc_2020_m1 <- nc_2020 %>% 
       mutate(prediction = predict(nc_incumbent, nc_2020))

# Model 2 prediction
nc_2020_m2 <- nc_2020 %>% 
  mutate(prediction = predict(nc_incumbent_midterm, nc_2020))

## IOWA

# Combine datasets and filter out irrelevant states
ia_data <- state_polls %>% 
  filter(state %in% c("Iowa")) %>% 
  filter(weeks_left <= 20) %>% 
  left_join(state_results %>% filter(state == "Iowa"), by = c("year", "state")) %>% 
  left_join(natl_popvote %>% select(-candidate, -pv, -pv2p, -winner, -prev_admin), by = c("year", "party")) %>%
  mutate(state_vote = ifelse(party == "republican", R_pv2p, D_pv2p)) %>%
  mutate(state_winner_party = ifelse(R_pv2p > D_pv2p, "republican", "democrat")) %>%
  mutate(state_winner = ifelse(state_winner_party == party, TRUE, FALSE)) %>%
  left_join(local_econ %>% filter(`State and area` == "Iowa", Month == "04"), by = c("year" = "Year"))%>% 
  filter(!is.na(Unemployed_prce)) %>%
  mutate(id = row_number())

# Model 1

# Create training and test data
ia_train <- ia_data %>%
  sample_frac(0.60)
ia_test <- ia_data %>%
  anti_join(ia_train, by = "id")

# Create models
ia_incumbent <- lm(state_vote ~ avg_poll + Unemployed_prce + incumbent + incumbent_party + avg_poll*incumbent_party + avg_poll*incumbent + Unemployed_prce*incumbent_party + Unemployed_prce*incumbent, data = ia_train)

# Test model on test data
ia_mod_part <- ia_test %>% 
  mutate(prediction = predict(ia_incumbent, ia_test),
         pred_winner = case_when(
           prediction > 50 ~ TRUE,
           prediction < 50 ~ FALSE
         ),
         correct = pred_winner == state_winner) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Test model on entire dataset
ia_mod_whole <- ia_data %>% 
  mutate(prediction = predict(ia_incumbent, ia_data),
         pred_winner = case_when(
           prediction > 50 ~ TRUE,
           prediction < 50 ~ FALSE
         ),
         correct = pred_winner == state_winner) %>%  
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Model 2

# Create models
ia_incumbent_midterm <- lm(state_vote ~ avg_poll + Unemployed_prce + incumbent_party + avg_poll*incumbent_party + Unemployed_prce*incumbent_party, data = ia_train)

# Test model on test data
ia_mod_mid_part <- ia_test %>% 
  mutate(prediction = predict(ia_incumbent_midterm, ia_test),
         pred_winner = case_when(
           prediction > 50 ~ TRUE,
           prediction < 50 ~ FALSE
         ),
         correct = pred_winner == state_winner) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Test model on entire dataset
ia_mod_mid_whole <- ia_data %>% 
  mutate(prediction = predict(ia_incumbent_midterm, ia_data),
         pred_winner = case_when(
           prediction > 50 ~ TRUE,
           prediction < 50 ~ FALSE
         ),
         correct = pred_winner == state_winner) %>%  
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Find 2020 unemployment rate in Iowa
unemp_2020_ia <- local_econ %>% 
  filter(Year == 2020, Month == "04", `State and area` == "Iowa") %>% 
  select(Unemployed_prce) %>% 
  pull()

# Model 1 & 2's 2020 prediction
ia_2020 <- polls_2020 %>% 
  filter(state == "Iowa") %>% 
  filter(answer %in% c("Biden", "Trump")) %>% 
  filter(!grepl("19$", start_date)) %>% 
  mutate(start_date = as.Date(start_date, "%m/%d/%y")) %>% 
  filter(start_date >= as.Date.character("2020-06-01")) %>% 
  group_by(answer) %>% 
  summarize(avg_poll = mean(pct), .groups = "drop_last") %>% 
  mutate(incumbent = c(FALSE, TRUE),
         incumbent_party = c(FALSE, TRUE),
         Unemployed_prce = unemp_2020_ia) 

# Model 1 prediction
ia_2020_m1 <- ia_2020 %>% 
  mutate(prediction = predict(ia_incumbent, ia_2020))

# Model 2 prediction
ia_2020_m2 <- ia_2020 %>% 
  mutate(prediction = predict(ia_incumbent_midterm, ia_2020))


# Image for blogpost
plot_usmap(include = c("IA", "NC"), color = c("blue", "red")) 

