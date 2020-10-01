#### Incumbency ####
#### Gov 1347: Election Analysis (2020)
#### TFs: Soubhik Barari, Sun Young Park
#### Assignment by Rick Brown

library(tidyverse)
library(usmap)

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
nc_incumbent <- lm(state_vote ~ avg_poll + Unemployed_prce, data = nc_train %>% filter(incumbent_party == TRUE))
nc_challenger <- lm(state_vote ~ avg_poll + Unemployed_prce, data = nc_train %>% filter(incumbent_party == FALSE))

# Test models on test data
nc_m1_test_part <- nc_test %>% 
  mutate(pred_incumbent = predict(nc_incumbent, nc_test),
         pred_challenger = predict(nc_challenger, nc_test),
         pred_winner = case_when(
           pred_incumbent > pred_challenger ~ incumbent,
           pred_incumbent < pred_challenger ~ !incumbent
         ),
         correct = pred_winner == incumbent) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Test models on entire dataset
nc_m1_test_whole <- nc_data %>% 
  mutate(pred_incumbent = predict(nc_incumbent, nc_data),
         pred_challenger = predict(nc_challenger, nc_data),
         pred_winner = case_when(
           pred_incumbent > pred_challenger ~ incumbent,
           pred_incumbent < pred_challenger ~ !incumbent
         ),
         correct = pred_winner == incumbent) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Model 2

# Select years when incumbent president ran for reelection
nc_midterm <- nc_data %>%
  filter(!year %in% c("1988", "2000", "2008", "2016"))

# Create training and test data for years when incumbent presidents ran for reelection
nc_train_midterm <- nc_midterm %>%
  sample_frac(0.60)
nc_test_midterm <- nc_midterm %>% 
  anti_join(nc_train_midterm, by = "id")

# Create models
nc_incumbent_midterm <- lm(state_vote ~ avg_poll + Unemployed_prce, data = nc_train_midterm %>% filter(incumbent == TRUE))
nc_challenger_midterm <- lm(state_vote ~ avg_poll + Unemployed_prce, data = nc_train_midterm %>% filter(incumbent == FALSE))

# Test models on test data
nc_m2_test_part <- nc_test_midterm %>% 
  mutate(pred_incumbent = predict(nc_incumbent_midterm, nc_test_midterm),
         pred_challenger = predict(nc_challenger_midterm, nc_test_midterm),
         pred_winner = case_when(
           pred_incumbent > pred_challenger ~ incumbent,
           pred_incumbent < pred_challenger ~ !incumbent
         ),
         correct = pred_winner == incumbent) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Test models on all data
nc_m2_test_whole <- nc_test_midterm %>% 
  mutate(pred_incumbent = predict(nc_incumbent_midterm, nc_test_midterm),
         pred_challenger = predict(nc_challenger_midterm, nc_test_midterm),
         pred_winner = case_when(
           pred_incumbent > pred_challenger ~ incumbent,
           pred_incumbent < pred_challenger ~ !incumbent
         ),
         correct = pred_winner == incumbent) %>% 
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
         Unemployed_prce = unemp_2020_nc) 

# Model 1 Prediction
nc_2020_m1 <- nc_2020 %>%  
  mutate(pred_vote = case_when(
    incumbent == TRUE ~ predict(nc_incumbent, nc_2020),
    incumbent == FALSE ~ predict(nc_challenger, nc_2020)
  ))

# Model 2 Prediction
nc_2020_m2 <- nc_2020 %>%  
  mutate(pred_vote = case_when(
    incumbent == TRUE ~ predict(nc_incumbent_midterm, nc_2020),
    incumbent == FALSE ~ predict(nc_challenger_midterm, nc_2020)
  ))


## IOWA

# Combine datasets and filter out irrelevant states
ia_data <- state_polls %>% 
  filter(state %in% c("Iowa")) %>% 
  filter(weeks_left <= 20) %>% 
  left_join(state_results %>% filter(state == "Iowa"), by = c("year", "state")) %>% 
  left_join(natl_popvote %>% select(-candidate, -pv, -pv2p, -winner, -prev_admin), by = c("year", "party")) %>%
  mutate(state_vote = ifelse(party == "republican", R_pv2p, D_pv2p)) %>%
  left_join(local_econ %>% filter(`State and area` == "Iowa", Month == "04"), by = c("year" = "Year"))%>% 
  filter(!is.na(Unemployed_prce)) %>%
  mutate(id = row_number())


# Model 1

# Make training and testing data
ia_train <- ia_data %>% 
  sample_frac(0.60)
ia_test <- ia_data %>% 
  anti_join(ga_train, by = "id")

# Create models
ia_incumbent <- lm(state_vote ~ avg_poll + Unemployed_prce, data = ia_train %>% filter(incumbent_party == TRUE))
ia_challenger <- lm(state_vote ~ avg_poll + Unemployed_prce, data = ia_train %>% filter(incumbent_party == FALSE))

# Test models on the test data
ia_m1_test_part <- ia_test %>% 
  mutate(pred_incumbent = predict(ia_incumbent, ia_test),
         pred_challenger = predict(ia_challenger, ia_test),
         pred_winner = case_when(
           pred_incumbent > pred_challenger ~ incumbent,
           pred_incumbent < pred_challenger ~ !incumbent
         ),
         correct = pred_winner == incumbent) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Test models on the entire data
ia_m1_test_whole <- ia_data %>% 
  mutate(pred_incumbent = predict(ia_incumbent, ia_data),
         pred_challenger = predict(ia_challenger, ia_data),
         pred_winner = case_when(
           pred_incumbent > pred_challenger ~ incumbent,
           pred_incumbent < pred_challenger ~ !incumbent
         ),
         correct = pred_winner == incumbent) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Model 2

# Select years when an incumbent was running for reelection
ia_midterm <- ia_data %>%
  filter(!year %in% c("1988", "2000", "2008", "2016"))

# Create training and test data for incumbent presidents running for reelection
ia_train_midterm <- ia_midterm %>%
  sample_frac(0.60)
ia_test_midterm <- ia_midterm %>% 
  anti_join(ia_train_midterm, by = "id")

# Create new models
ia_incumbent_midterm <- lm(state_vote ~ avg_poll + Unemployed_prce, data = ia_train_midterm %>% filter(incumbent == TRUE))
ia_challenger_midterm <- lm(state_vote ~ avg_poll + Unemployed_prce, data = ia_train_midterm %>% filter(incumbent == FALSE))


# Test models on part of the data
ia_m2_test_part <- ia_test_midterm %>% 
  mutate(pred_incumbent = predict(ia_incumbent_midterm, ia_test_midterm),
         pred_challenger = predict(ia_challenger_midterm, ia_test_midterm),
         pred_winner = case_when(
           pred_incumbent > pred_challenger ~ incumbent,
           pred_incumbent < pred_challenger ~ !incumbent
         ),
         correct = pred_winner == incumbent) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Test models on entire dataset
ia_m2_test_whole <- ia_test_midterm %>% 
  mutate(pred_incumbent = predict(ia_incumbent_midterm, ia_test_midterm),
         pred_challenger = predict(ia_challenger_midterm, ia_test_midterm),
         pred_winner = case_when(
           pred_incumbent > pred_challenger ~ incumbent,
           pred_incumbent < pred_challenger ~ !incumbent
         ),
         correct = pred_winner == incumbent) %>% 
  summarize(correct = mean(correct)) %>% 
  mutate(incorrect = 1 - correct)

# Find 2020 unemployment data for Iowa
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
         Unemployed_prce = unemp_2020_ia) 

# Model 1
ia_2020_m1 <- ia_2020 %>%  
  mutate(pred_vote = case_when(
    incumbent == TRUE ~ predict(ia_incumbent, ia_2020),
    incumbent == FALSE ~ predict(ia_challenger, ia_2020)
  ))

# Model 2
ia_2020_m2 <- ia_2020 %>%  
  mutate(pred_vote = case_when(
    incumbent == TRUE ~ predict(ia_incumbent_midterm, ia_2020),
    incumbent == FALSE ~ predict(ia_challenger_midterm, ia_2020)
  ))

# Image for blogpost
plot_usmap(include = c("IA", "NC"), color = "blue") 

