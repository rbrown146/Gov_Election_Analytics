library(tidyverse)
library(ggplot2)
library(usmap)
library(ggthemes)

###### Data gathering and formatting #########

# Import county results from 2000-2016
pvcounty_old    <- read_csv("~/Downloads/Gov/popvote_bycounty_2000-2016.csv") %>%
  mutate(winner = ifelse(D_win_margin > 0, "Democratic", "Republican"))

# Import county results from 2020
pvcounty_20    <- read_csv("~/Downloads/Gov/popvote_bycounty_2020.csv") %>%
  tail(-1) %>%
  select(fips = `FIPS`, biden = `Joseph R. Biden Jr.`, trump = `Donald J. Trump`, county_name = `Geographic Name`)

# Determine county winner in 2020
pvcounty_20 <- pvcounty_20 %>%
  mutate(winner = ifelse(as.numeric(biden) > as.numeric(trump), "Democratic", "Republican"))

# Create a slimmer database of 2020 results for merging
join <- pvcounty_20 %>%
  mutate(year = 2020, fips = as.numeric(fips)) %>%
  select(year, winner, fips, county = county_name)

# Merge slim 2020 results to 2000-2016 results, then select only 2000 and 2020 results
swing_county_00_20 <- pvcounty_old %>%
  filter(year %in% c(2000, 2020)) %>%
  bind_rows(join)

# Determine pivot counties, 2000 vs 2020 
swing_county_00_20 <- swing_county_00_20 %>% 
  group_by(fips) %>%
  mutate(counter = ifelse(winner == "Republican", 1, 0), diff = sum(counter)) %>%
  filter(diff == 1, year == 2000)

# Merge slim 2020 results to 2000-2016 results, then select only 2016 and 2020 results
swing_county_16_20 <- pvcounty_old %>%
  filter(year %in% c(2016, 2020)) %>%
  bind_rows(join)

# Determine pivot counties, 2016 vs 2020
swing_county_16_20 <- swing_county_16_20 %>% 
  group_by(fips) %>%
  mutate(counter = ifelse(winner == "Republican", 1, 0), diff = sum(counter)) %>%
  filter(diff == 1, year == 2016)

##### Plotting Results ########

# Plot pivot counties, 2000 vs 2020
plot_usmap(data = swing_county_00_20, regions = "counties", values = "winner") +
  scale_fill_manual(values = c("blue", "red"), name = "Pivot Counties, 2000 vs. 2020\n(Colored by color of winning party in 2000)") +
  theme_void()

# Plot pivot counties, 2016 vs 2020
plot_usmap(data = swing_county_16_20, regions = "counties", values = "winner") +
  scale_fill_manual(values = c("blue", "red"), name = "Pivot Counties, 2016 vs. 2020\n(Colored by color of winning party in 2016)") +
  theme_void()

# Filter results for plotting the 2016 election
pvcounty_16 <- pvcounty_old %>%
  filter(year == 2016)

# Filter results for plotting the 2012 election
pvcounty_12 <- pvcounty_old %>%
  filter(year == 2012)

# Filter results for plotting the 2008 election
pvcounty_08 <- pvcounty_old %>%
  filter(year == 2008)

# Filter results for plotting the 2004 election
pvcounty_04 <- pvcounty_old %>%
  filter(year == 2004)

# Filter results for plotting the 2000 election
pvcounty_00 <- pvcounty_old %>%
  filter(year == 2000)

# County results, 2020
plot_usmap(data = pvcounty_20, regions = "counties", values = "winner") +
  scale_fill_manual(values = c("blue", "red"), name = "County PV Winner 2020") +
  theme_void()

# County results, 2016
plot_usmap(data = pvcounty_16, regions = "counties", values = "winner") +
  scale_fill_manual(values = c("blue", "red"), name = "County PV Winner 2016") +
  theme_void()

# County results, 2012
plot_usmap(data = pvcounty_12, regions = "counties", values = "winner") +
  scale_fill_manual(values = c("blue", "red"), name = "County PV Winner 2012") +
  theme_void()

# County results, 2008
plot_usmap(data = pvcounty_08, regions = "counties", values = "winner") +
  scale_fill_manual(values = c("blue", "red"), name = "County PV Winner 2008") +
  theme_void()

# County results, 2004
plot_usmap(data = pvcounty_04, regions = "counties", values = "winner") +
  scale_fill_manual(values = c("blue", "red"), name = "County PV Winner 2004") +
  theme_void()

# County results, 2000
plot_usmap(data = pvcounty_00, regions = "counties", values = "winner") +
  scale_fill_manual(values = c("blue", "red"), name = "County PV Winner 2000") +
  theme_void()
