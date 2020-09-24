#### Polling ####
#### Gov 1347: Election Analysis (2020)
#### TFs: Soubhik Barari, Sun Young Park

####----------------------------------------------------------#
#### Pre-amble ####
####----------------------------------------------------------#

## install via `install.packages("name")`
library(tidyverse)
library(ggplot2)

## set working directory here
setwd("~")

####----------------------------------------------------------#
#### Quantitatively describing the polls ####
#### - How do polls fluctuate across state, time, and year?
####----------------------------------------------------------#

# Read in data
popvote_df <- read_csv("popvote_1948-2016.csv")
poll_df <- read_csv("pollavg_1968-2016.csv")
poll_state <- read.csv("pollavg_bystate_1968-2016.csv")
actual_state <- read.csv("popvote_bystate_1948-2016.csv") %>%
  mutate(state_winner = ifelse(R_pv2p > D_pv2p, "republican", "democrat"))

# Create a single dataset
state_10_weeks <- poll_state %>%
  filter(weeks_left <= 1, weeks_left >= 0) %>%
  group_by(year, party, state) %>%
  top_n(1, poll_date) %>%
  left_join(actual_state, by = c("year"="year", "state"="state")) %>%
  select(-total, -D, -R) %>%
  rename(state_R_pv2p = R_pv2p, state_D_pv2p = D_pv2p) %>%
  left_join(popvote_df, by= c("year"="year", "party"="party")) %>%
  rename(natl_winner = winner) %>%
  group_by(state, year) %>% arrange(state, year, -natl_winner) %>%
  mutate(state_pv2p = ifelse(party == "republican", state_R_pv2p, state_D_pv2p)) %>%
  summarise(natl_pv2p_margin=first(pv2p)-last(pv2p), 
            natl_pv2p_winner=first(pv2p),
            state_pv2p_winner = first(state_pv2p),
            state_pv2p_margin = first(state_pv2p)-last(state_pv2p),
            avg_state_poll_margin=first(avg_poll)-last(avg_poll))

# Wisconsin

state_10_weeks %>%
  filter(state == "Wisconsin") %>%
  ggplot(aes(x=avg_state_poll_margin, y=natl_pv2p_margin,
             label=year)) + 
  ggtitle("Wisconsin") +
  geom_text() +
  xlim(c(-5, 25)) + ylim(c(-5, 25)) +
  geom_abline(slope=1, lty=2) +
  geom_vline(xintercept=0, alpha=0.2) + 
  geom_hline(yintercept=0, alpha=0.2) +
  xlab("Winner's average polling margin 0-1 weeks out") +
  ylab("Winner's"~bold(national)~"two-party voteshare margin") +
  theme_gray() +
  theme(plot.title = element_text(hjust = 0.5))

state_10_weeks %>%
  filter(state == "Wisconsin") %>%
  ggplot(aes(x=avg_state_poll_margin, y=state_pv2p_margin,
             label=year)) + 
  geom_text() + 
  ggtitle("Wisconsin") +
  xlim(c(-5, 25)) + ylim(c(-5, 25)) +
  geom_abline(slope=1, lty=2) +
  geom_vline(xintercept=0, alpha=0.2) + 
  geom_hline(yintercept=0, alpha=0.2) +
  xlab("Winner's average state polling margin 0-1 weeks out") +
  ylab("Winner's"~bold(state)~"two-party voteshare margin") +
  theme_gray() +
  theme(plot.title = element_text(hjust = 0.5))

## Correlations and R squared
wisconsin <- state_10_weeks %>%
  filter(state == "Wisconsin")

cor(wisconsin$natl_pv2p_margin, wisconsin$avg_state_poll_margin) #0.87
cor(wisconsin$state_pv2p_margin, wisconsin$avg_state_poll_margin) #0.80

reg_wisc_2016 <- lm(natl_pv2p_margin ~ avg_state_poll_margin, wisconsin)
summary(reg_wisc_2016) #r-squared = 0.76

reg_state_wisc_2016 <- lm(state_pv2p_margin ~ avg_state_poll_margin, wisconsin)
summary(reg_state_wisc_2016) #r-squared = 0.64

## Correlations and R squared Excluding 2016
wisconsin_pre_2016 <- state_10_weeks %>%
  filter(state == "Wisconsin", year != 2016)

cor(wisconsin_pre_2016$natl_pv2p_margin, wisconsin_pre_2016$avg_state_poll_margin) #0.82
cor(wisconsin_pre_2016$state_pv2p_margin, wisconsin_pre_2016$avg_state_poll_margin) #0.83

reg_wisc_non_2016 <- lm(natl_pv2p_margin ~ avg_state_poll_margin, wisconsin_pre_2016)
summary(reg_wisc_non_2016) #r-squared = 0.68

reg_state_wisc_non_2016 <- lm(state_pv2p_margin ~ avg_state_poll_margin, wisconsin_pre_2016)
summary(reg_state_wisc_non_2016) #r-squared = 0.70

# Michigan

state_10_weeks %>%
  filter(state == "Michigan") %>%
  ggplot(aes(x=avg_state_poll_margin, y=natl_pv2p_margin,
             label=year)) + 
  ggtitle("Michigan") +
  geom_text() +
  xlim(c(-5, 25)) + ylim(c(-5, 25)) +
  geom_abline(slope=1, lty=2) +
  geom_vline(xintercept=0, alpha=0.2) + 
  geom_hline(yintercept=0, alpha=0.2) +
  xlab("Winner's average polling margin 0-1 weeks out") +
  ylab("Winner's"~bold(national)~"two-party voteshare margin") +
  theme_gray() +
  theme(plot.title = element_text(hjust = 0.5))

state_10_weeks %>%
  filter(state == "Michigan") %>%
  ggplot(aes(x=avg_state_poll_margin, y=state_pv2p_margin,
             label=year)) + 
  geom_text() + 
  ggtitle("Michigan") +
  xlim(c(-5, 25)) + ylim(c(-5, 25)) +
  geom_abline(slope=1, lty=2) +
  geom_vline(xintercept=0, alpha=0.2) + 
  geom_hline(yintercept=0, alpha=0.2) +
  xlab("Winner's average state polling margin 0-1 weeks out") +
  ylab("Winner's"~bold(state)~"two-party voteshare margin") +
  theme_gray() +
  theme(plot.title = element_text(hjust = 0.5))

## Correlations and R squared
michigan <- state_10_weeks %>%
  filter(state == "Michigan")

cor(michigan$natl_pv2p_margin, michigan$avg_state_poll_margin) #0.80
cor(michigan$state_pv2p_margin, michigan$avg_state_poll_margin) #0.95

reg_mi_2016 <- lm(natl_pv2p_margin ~ avg_state_poll_margin, michigan)
summary(reg_mi_2016) #r-squared = 0.64

reg_state_mi_2016 <- lm(state_pv2p_margin ~ avg_state_poll_margin, michigan)
summary(reg_state_mi_2016) #r-squared = 0.90

## Correlations and R squared Excluding 2016
michigan_pre_2016 <- state_10_weeks %>%
  filter(state == "Michigan", year != 2016)

cor(michigan_pre_2016$natl_pv2p_margin, michigan_pre_2016$avg_state_poll_margin) #0.76
cor(michigan_pre_2016$state_pv2p_margin, michigan_pre_2016$avg_state_poll_margin) #0.95

reg_mi_non_2016 <- lm(natl_pv2p_margin ~ avg_state_poll_margin, michigan_pre_2016)
summary(reg_mi_non_2016) #r-squared = 0.58

reg_state_mi_non_2016 <- lm(state_pv2p_margin ~ avg_state_poll_margin, michigan_pre_2016)
summary(reg_state_mi_non_2016) #r-squared = 0.90

# Florida
  
state_10_weeks %>%
  filter(state == "Florida") %>%
  ggplot(aes(x=avg_state_poll_margin, y=natl_pv2p_margin,
             label=year)) + 
  ggtitle("Florida") +
  geom_text() +
  xlim(c(-5, 25)) + ylim(c(-5, 25)) +
  geom_abline(slope=1, lty=2) +
  geom_vline(xintercept=0, alpha=0.2) + 
  geom_hline(yintercept=0, alpha=0.2) +
  xlab("Winner's average polling margin 0-1 weeks out") +
  ylab("Winner's"~bold(national)~"two-party voteshare margin") +
  theme_gray() +
  theme(plot.title = element_text(hjust = 0.5))

state_10_weeks %>%
  filter(state == "Florida") %>%
  ggplot(aes(x=avg_state_poll_margin, y=state_pv2p_margin,
             label=year)) + 
  geom_text() + 
  ggtitle("Florida") +
  xlim(c(-5, 25)) + ylim(c(-5, 25)) +
  geom_abline(slope=1, lty=2) +
  geom_vline(xintercept=0, alpha=0.2) + 
  geom_hline(yintercept=0, alpha=0.2) +
  xlab("Winner's average state polling margin 0-1 weeks out") +
  ylab("Winner's"~bold(state)~"two-party voteshare margin") +
  theme_gray() +
  theme(plot.title = element_text(hjust = 0.5))

## Correlations and R squared
florida <- state_10_weeks %>%
  filter(state == "Florida")

cor(florida$natl_pv2p_margin, florida$avg_state_poll_margin) #0.76
cor(florida$state_pv2p_margin, florida$avg_state_poll_margin) #0.96

reg_fl_2016 <- lm(natl_pv2p_margin ~ avg_state_poll_margin, florida)
summary(reg_fl_2016) #r-squared = 0.57

reg_state_fl_2016 <- lm(state_pv2p_margin ~ avg_state_poll_margin, florida)
summary(reg_state_fl_2016) #r-squared = 0.92

## Correlations and R squared Excluding 2016
florida_pre_2016 <- state_10_weeks %>%
  filter(state == "Florida", year != 2016)

cor(florida_pre_2016$natl_pv2p_margin, florida_pre_2016$avg_state_poll_margin) #0.77
cor(florida_pre_2016$state_pv2p_margin, florida_pre_2016$avg_state_poll_margin) #0.96

reg_fl_non_2016 <- lm(natl_pv2p_margin ~ avg_state_poll_margin, florida_pre_2016)
summary(reg_fl_non_2016) #r-squared = 0.59

reg_state_fl_non_2016 <- lm(state_pv2p_margin ~ avg_state_poll_margin, florida_pre_2016)
summary(reg_state_fl_non_2016) #r-squared = 0.92

# Missouri

state_10_weeks %>%
  filter(state == "Missouri") %>%
  ggplot(aes(x=avg_state_poll_margin, y=natl_pv2p_margin,
             label=year)) + 
  ggtitle("Missouri") +
  geom_text() +
  xlim(c(-5, 25)) + ylim(c(-5, 25)) +
  geom_abline(slope=1, lty=2) +
  geom_vline(xintercept=0, alpha=0.2) + 
  geom_hline(yintercept=0, alpha=0.2) +
  xlab("Winner's average polling margin 0-1 weeks out") +
  ylab("Winner's"~bold(national)~"two-party voteshare margin") +
  theme_gray() +
  theme(plot.title = element_text(hjust = 0.5))

state_10_weeks %>%
  filter(state == "Missouri") %>%
  ggplot(aes(x=avg_state_poll_margin, y=state_pv2p_margin,
             label=year)) + 
  geom_text() + 
  ggtitle("Missouri") +
  xlim(c(-5, 25)) + ylim(c(-5, 25)) +
  geom_abline(slope=1, lty=2) +
  geom_vline(xintercept=0, alpha=0.2) + 
  geom_hline(yintercept=0, alpha=0.2) +
  xlab("Winner's average state polling margin 0-1 weeks out") +
  ylab("Winner's"~bold(state)~"two-party voteshare margin") +
  theme_gray() +
  theme(plot.title = element_text(hjust = 0.5))

## Correlations and R squared
missouri <- state_10_weeks %>%
  filter(state == "Missouri")

cor(missouri$natl_pv2p_margin, missouri$avg_state_poll_margin) #0.02
cor(missouri$state_pv2p_margin, missouri$avg_state_poll_margin) #0.93

reg_mo_2016 <- lm(natl_pv2p_margin ~ avg_state_poll_margin, missouri)
summary(reg_mo_2016) #r-squared = 0.00

reg_state_mo_2016 <- lm(state_pv2p_margin ~ avg_state_poll_margin, missouri)
summary(reg_state_mo_2016) #r-squared = 0.87

## Correlations and R squared Excluding 2016
missouri_pre_2016 <- state_10_weeks %>%
  filter(state == "Missouri", year != 2016)

cor(missouri_pre_2016$natl_pv2p_margin, missouri_pre_2016$avg_state_poll_margin) #0.34
cor(missouri_pre_2016$state_pv2p_margin, missouri_pre_2016$avg_state_poll_margin) #0.98

reg_mo_non_2016 <- lm(natl_pv2p_margin ~ avg_state_poll_margin, missouri_pre_2016)
summary(reg_mo_non_2016) #r-squared = 0.11

reg_state_mo_non_2016 <- lm(state_pv2p_margin ~ avg_state_poll_margin, missouri_pre_2016)
summary(reg_state_mo_non_2016) #r-squared = 0.96

