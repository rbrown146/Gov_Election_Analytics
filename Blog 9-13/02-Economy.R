#### Economy ####
#### Gov 1347: Election Analysis (2020)
#### TFs: Soubhik Barari, Sun Young Park

####----------------------------------------------------------#
#### Pre-amble ####
####----------------------------------------------------------#

## install via `install.packages("name")`
library(tidyverse)
library(ggplot2)
library(broom)

## set working directory here
setwd("~/Downloads")

####----------------------------------------------------------#
#### The relationship between economy and PV ####
####----------------------------------------------------------#

# state_ec <- read_csv("local.csv")%>%
#   filter(Month %in% c("04", "05", "06")) %>%
#   group_by(`State and area`, Year) %>%
#   mutate(Quarter_2_avg = sum(Unemployed_prce)/n()) %>%
#   filter(Month == "04") %>%
#   select(`State and area`, Year, Quarter_2_avg)

# %>%
#   nest() %>%
#   mutate(testing = map(data, ~ lm(incumbent_vote ~ state_unemploy, data = .x))) %>%
#   mutate(state_intercept_estimate = map(testing, ~ pluck(tidy(.x), "estimate", 1))) %>%
#   mutate(state_intercept_std_error = map(testing, ~ pluck(tidy(.x), "std.error", 1))) %>%
#   mutate(nat_data = map(data, ~ lm(incumbent_vote ~ natl_unemploy, data = .x))) %>%
#   mutate(nat_intercept_estimate = map(nat_data, ~ pluck(tidy(.x), "estimate", 1))) %>%
#   mutate(nat_intercept_std_error = map(nat_data, ~ pluck(tidy(.x), "std.error", 1)))
# 
# mutate(nom_congress = map(data, ~ lm(nominate_dim1 ~ party * age, data = .x)))%>%
#   mutate(dem_coeff = map(nom_congress, ~ pluck(tidy(.x), "estimate", 1))) %>%
#   mutate(r_squared = map(nom_congress, ~ pluck(glance(.x), "r.squared")))
# 
# lm_econ <- lm(pv2p ~ GDP_growth_qt, data = dat)
# summary(lm_econ)

state_ec <- read_csv("local.csv")%>%
  filter(Month %in% c("04", "05", "06")) %>%
  filter(Month == "04") %>%
  select(`State and area`, Year, Unemployed_prce)
state_vote <- read_csv("popvote_bystate_1948-2016.csv") 

state_data <- state_vote %>%
  select(-D, -R, -total) %>%
  mutate(incumbent_vote = case_when(
    year == 1976 ~ R_pv2p,
    year == 1980 ~ D_pv2p,
    year == 1984 ~ R_pv2p,
    year == 1988 ~ R_pv2p,
    year == 1992 ~ R_pv2p,
    year == 1996 ~ D_pv2p,
    year == 2000 ~ D_pv2p,
    year == 2004 ~ R_pv2p,
    year == 2008 ~ R_pv2p,
    year == 2012 ~ D_pv2p,
    year == 2016 ~ D_pv2p
  )) %>%
  select(-R_pv2p, -D_pv2p) %>%
  left_join(state_ec, by= c("state" = "State and area", "year" = "Year")) %>%
  left_join(dat %>% select(year, winner, unemployment, pv2p), by= "year") %>%
  rename(natl_unemploy = unemployment, state_unemploy = Unemployed_prce) %>%
  group_by(state) 

mi_data <- state_data %>%
  filter(state == "Michigan") %>%
  drop_na()

mi_data %>%
  ggplot(aes(x=state_unemploy, y=incumbent_vote,
             label=year)) + 
  geom_text() +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Second quarter Unemployment") +
  ylab("Incumbent party's national popular pv2p") +
  theme_bw()

state_data %>%
  drop_na() %>%
  ggplot(aes(x=state_unemploy, y=incumbent_vote,
             label=year)) + 
  geom_text() +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Second quarter Unemployment") +
  ylab("Incumbent party's state popular pv2p") +
  theme_bw()

mi_data %>%
  ggplot(aes(x=natl_unemploy, y=incumbent_vote,
             label=year)) + 
  geom_text() +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Second quarter Unemployment") +
  ylab("Incumbent party's national popular pv2p") +
  theme_bw()


state_lm_econ <- lm(incumbent_vote ~ state_unemploy, data = state_data)
summary(state_lm_econ)

state_lm_econ_2 <- lm(incumbent_vote ~ natl_unemploy, data = state_data)
summary(state_lm_econ_2)

mi_lm_econ <- lm(incumbent_vote ~ state_unemploy, data = mi_data)
summary(mi_lm_econ)

natl_mi_lm_econ <- lm(incumbent_vote ~ natl_unemploy, data = mi_data)
summary(natl_mi_lm_econ)

----------------------------------
  
economy_df <- read_csv("econ.csv") 
popvote_df <- read_csv("popvote_1948-2016.csv") 

GDP_new <- economy_df %>%
  subset(year == 2020 & quarter == 2) %>%
  select(GDP_growth_qt)

RDI_new <- economy_df %>%
  subset(year == 2020 & quarter == 2) %>%
  select(RDI_growth)

unemployment_new <- economy_df %>%
  subset(year == 2020 & quarter == 2) %>%
  select(unemployment)

stock_open_new <- economy_df %>%
  subset(year == 2020 & quarter == 2) %>%
  select(stock_open)

stock_volume_new <- economy_df %>%
  subset(year == 2020 & quarter == 2) %>%
  select(stock_volume)

inflation_new <- economy_df %>%
  subset(year == 2020 & quarter == 2) %>%
  select(inflation)

dat <- popvote_df %>% 
  filter(incumbent_party == TRUE) %>%
  select(year, winner, pv2p) %>%
  left_join(economy_df %>% filter(quarter == 2))

## scatterplot + line for GDP
dat %>%
  ggplot(aes(x=GDP_growth_qt, y=pv2p,
             label=year)) + 
  geom_text() +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Second quarter GDP growth") +
  ylab("Incumbent party's national popular pv2p") +
  theme_bw()

summary(lm(pv2p ~ GDP_growth_qt, data = dat))
predict(lm_econ, GDP_new)

outsamp_mod  <- lm(pv2p ~ GDP_growth_qt, dat[dat$year != 2016,])
outsamp_pred <- predict(outsamp_mod, dat[dat$year == 2016,])
outsamp_true <- dat$pv2p[dat$year == 2016] 

outsamp_pred

# RDI 
dat %>%
  ggplot(aes(x=RDI_growth, y=pv2p,
             label=year)) + 
  geom_text() +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Second Quarter RDI growth") +
  ylab("Incumbent party's national popular pv2p") +
  theme_bw()

summary(lm(pv2p ~ RDI_growth, data = dat))
lm_rdi <- lm(pv2p ~ RDI_growth, data = dat)
predict(lm_rdi, RDI_new)

outsamp_mod_rdi  <- lm(pv2p ~ RDI_growth, dat[dat$year != 2016,])
outsamp_pred_rdi <- predict(outsamp_mod_rdi, dat[dat$year == 2016,])
outsamp_true_rdi <- dat$pv2p[dat$year == 2016] 

outsamp_pred_rdi
outsamp_true_rdi

# Unemployment
dat %>%
  ggplot(aes(x=unemployment, y=pv2p,
             label=year)) + 
  geom_text() +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Second Quarter Unemployment Rate") +
  ylab("Incumbent party's national popular pv2p") +
  theme_bw()

summary(lm(pv2p ~ unemployment, data = dat))
lm_unemp <- lm(pv2p ~ unemployment, data = dat)
predict(lm_unemp, unemployment_new)

outsamp_mod_unemployment  <- lm(pv2p ~ unemployment, dat[dat$year != 2016,])
outsamp_pred_unemployment <- predict(outsamp_mod_unemployment, dat[dat$year == 2016,])

outsamp_pred_unemployment
outsamp_true_rdi

# Inflation
dat %>%
  ggplot(aes(x=inflation, y=pv2p,
             label=year)) + 
  geom_text() +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Second Quarter Inflation Rate") +
  ylab("Incumbent party's national popular pv2p") +
  theme_bw()

summary(lm(pv2p ~ inflation, data = dat))
lm_inflation <- lm(pv2p ~ inflation, data = dat)
predict(lm_inflation, inflation_new)

outsamp_mod_inflation  <- lm(pv2p ~ inflation, dat[dat$year != 2016,])
outsamp_pred_inflation <- predict(outsamp_mod_inflation, dat[dat$year == 2016,])

outsamp_pred_inflation

#stock_open
dat %>%
  ggplot(aes(x=stock_open, y=pv2p,
             label=year)) + 
  geom_text() +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Second Quarter Stock Open Price") +
  ylab("Incumbent party's national popular pv2p") +
  theme_bw()

summary(lm(pv2p ~ stock_open, data = dat))
lm_stock_open <- lm(pv2p ~ stock_open, data = dat)
predict(lm_stock_open, stock_open_new)

outsamp_mod_stock_open  <- lm(pv2p ~ stock_open, dat[dat$year != 2016,])
outsamp_pred_stock_open <- predict(outsamp_mod_stock_open, dat[dat$year == 2016,])

outsamp_pred_stock_open

#stock_volume
dat %>%
  ggplot(aes(x=stock_volume, y=pv2p,
             label=year)) + 
  geom_text() +
  geom_smooth(method="lm", formula = y ~ x) +
  geom_hline(yintercept=50, lty=2) +
  geom_vline(xintercept=0.01, lty=2) + # median
  xlab("Second Quarter Stock Volume") +
  ylab("Incumbent party's national popular pv2p") +
  theme_bw()

summary(lm(pv2p ~ stock_volume, data = dat))
lm_stock_volume <- lm(pv2p ~ stock_volume, data = dat)
predict(lm_stock_volume, stock_volume_new)

outsamp_mod_sv  <- lm(pv2p ~ stock_volume, dat[dat$year != 2016,])
outsamp_pred_sv <- predict(outsamp_mod_sv, dat[dat$year == 2016,])
outsamp_true_sv <- dat$pv2p[dat$year == 2016] 

outsamp_pred_sv

years_outsamp <- sample(dat$year, 8)
mod_sv <- lm(pv2p ~ stock_volume,
          dat[!(dat$year %in% years_outsamp),])

outsamp_mod_sv
outsamp_pred_sv
outsamp_true_sv
mod_sv

predict(lm_econ, GDP_new)

## fit a model
lm_econ <- lm(pv2p ~ GDP_growth_qt, data = dat)
summary(lm_econ)

summary(lm(pv2p ~ GDP_growth_qt, data = dat))

dat %>%
  ggplot(aes(x=GDP_growth_qt, y=pv2p,
             label=year)) + 
    geom_text(size = 8) +
    geom_smooth(method="lm", formula = y ~ x) +
    geom_hline(yintercept=50, lty=2) +
    geom_vline(xintercept=0.01, lty=2) + # median
    xlab("Q2 GDP growth (X)") +
    ylab("Incumbent party PV (Y)") +
    theme_bw() +
    ggtitle("Y = 49.44 + 2.969 * X") + 
    theme(axis.text = element_text(size = 20),
          axis.title = element_text(size = 24),
          plot.title = element_text(size = 32))

## model fit 

#TODO

## model testing: leave-one-out
outsamp_mod  <- lm(pv2p ~ GDP_growth_qt, dat[dat$year != 2016,])
outsamp_pred <- predict(outsamp_mod, dat[dat$year == 2016,])
outsamp_true <- dat$pv2p[dat$year == 2016] 

## model testing: cross-validation (one run)
years_outsamp <- sample(dat$year, 8)
mod <- lm(pv2p ~ GDP_growth_qt,
          dat[!(dat$year %in% years_outsamp),])

outsamp_pred <- #TODO
  
## model testing: cross-validation (1000 runs)
outsamp_errors <- sapply(1:1000, function(i){
  #TODO
})

hist(outsamp_errors,
     xlab = "",
     main = "mean out-of-sample residual\n(1000 runs of cross-validation)")

## prediction for 2020
GDP_new <- economy_df %>%
    subset(year == 2020 & quarter == 2) %>%
    select(GDP_growth_qt)

predict(lm_econ, GDP_new)

#TODO: predict uncertainty
  
## extrapolation?
##   replication of: https://nyti.ms/3jWdfjp

economy_df %>%
  subset(quarter == 2 & !is.na(GDP_growth_qt)) %>%
  ggplot(aes(x=year, y=GDP_growth_qt,
             fill = (GDP_growth_qt > 0))) +
  geom_col() +
  xlab("Year") +
  ylab("GDP Growth (Second Quarter)") +
  ggtitle("The percentage decrease in G.D.P. is by far the biggest on record.") +
  theme_bw() +
  theme(legend.position="none",
        plot.title = element_text(size = 12,
                                  hjust = 0.5,
                                  face="bold"))
