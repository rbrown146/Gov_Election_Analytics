library(tidyverse)
library(usmap)
library(readxl)
library(sjPlot)
library(stargazer)

###### Prepare Data ##############

# Read in county vote data for 2012 & 2016
county_16 <- read_csv("~/Downloads/Gov/popvote_bycounty_2000-2016.csv")%>%
  select(fips, D_win_margin, year, county)

# Read in county vote data for 2020
county_20 <- read_csv("~/Downloads/Gov/popvote_bycounty_2020.csv") %>%
  tail(-1) %>%
  select(fips = `FIPS`, biden = `Joseph R. Biden Jr.`, trump = `Donald J. Trump`, county_name = `Geographic Name`) 
 
# Read in county density data
density <- read_excel("~/Downloads/NCHSURCodes2013.xlsx") %>%
  select(fips = `FIPS code`, dens_2013 = `2013 code`, dens_2006 = `2006 code`) %>%
  filter(dens_2013 != 4) %>%
  mutate(urban = ifelse(dens_2013 == 1,1,0),
         suburban = ifelse(dens_2013 %in% c(2,3),1,0),
         rural = ifelse(dens_2013 %in% c(5,6),1,0), 
         density=ifelse(urban == 1, "Urban", ifelse(rural == 1, "Rural", "Suburban"))) 

# Determine county winner in 2020 and prepare df for merging
county_20 <- county_20 %>%
  mutate(year = 2020, 
         fips = as.numeric(fips),
         D_win_margin = (as.numeric(biden) - as.numeric(trump))/(as.numeric(biden)+as.numeric(trump))) %>%
  select(year, fips, county = county_name, D_win_margin) %>%
  mutate(D_win_margin = D_win_margin *100)

# Extract total two party vote by county, 2020 election
weights <- read_csv("~/Downloads/Gov/popvote_bycounty_2020.csv") %>%
  tail(-1) %>%
  select(fips = `FIPS`, biden = `Joseph R. Biden Jr.`, trump = `Donald J. Trump`, county = `Geographic Name`) %>%
  mutate(total = as.numeric(biden)+as.numeric(trump), fips = as.numeric(fips)) %>%
  select(fips, total, county)

# Merge slim 2020 results to 2000-2016 results, then select only 2000 and 2020 results
county_vote <- county_16 %>%
  filter(year %in% c(2012, 2016, 2020)) %>%
  bind_rows(county_20) %>%
  spread(year, D_win_margin) %>%
  left_join(density) %>%
  left_join(weights) %>%
  filter(!is.na(urban), !is.na(`2012`), !is.na(`2020`)) %>%
  mutate(shift_12_16 = as.numeric(`2016`) - as.numeric(`2012`),
         shift_16_20 = as.numeric(`2020`) - as.numeric(`2016`),
         shift_12_20 = as.numeric(`2020`) - as.numeric(`2012`),
         biden_gain = shift_16_20 * .01 * total)


###### Plotting Graphs #############

# Calculate the percentage of total new Biden votes (based on vote share) from each county type 
change <- county_vote %>%
  group_by(density) %>%
  summarise(gain = sum(biden_gain)) %>%
  mutate(total = sum(gain),
         percent = 100 * gain/total)

# Source of National Biden Vote Share Gain Over Trump (Based on Vote Share Change from 2016)
ggplot(change, aes(x=density, y=percent, fill=density)) + 
  geom_bar(stat="identity") +
  geom_text(aes(label = paste0(round(percent,2),"%"),y=percent/2),size = 3, color="white") +
  geom_hline(yintercept=0)+
  labs(title="Source of National Biden Vote Share Gain Over Trump (Based on Vote Share Change from 2016)", x="County Type", y="Fraction of Total Vote Share Gain") +
  theme(plot.title = element_text(hjust = 0.5)) +
  scale_fill_manual(values = c("red","blue", "blue")) +
  guides(fill=FALSE)

# Calculate mean Democratic vote share by County in 2016 and 2020
mean_county_dem <- county_vote %>%
  group_by(density) %>%
  summarise(v16 =mean(`2016`), v20 = mean(`2020`)) %>%
  mutate(v16 = (v16+100)/2, v20 = (v20+100)/2, party = "Democratic") 

# Create df of mean Dem and GOP vote share by county in 2016 and 2020
mean_county <- mean_county_16 %>%
  mutate(party = "Republican", v16 = 100-v16, v20=100-v20) %>%
  bind_rows(mean_county_dem)

# Create labels for 2020 Dem. County vote share figure
mean_county$labelpos <- ifelse(mean_county$party=="Republican",
                                mean_county$v20/200, 1 - mean_county$v20/200)

# Create labels for 2016 Dem. County vote share figure
mean_county$labelpos16 <- ifelse(mean_county$party=="Republican",
                               mean_county$v16/200, 1 - mean_county$v16/200)

# 2020 Democratic County Vote share
ggplot(mean_county, aes(fill=party, x=density, y=v20)) + 
  geom_bar(position="fill", stat="identity") +
  scale_fill_manual(values = c("blue","red")) +
  labs(title="Two Party Vote by County, 2020", x="County Type", y="Vote share", fill="Party") +
  scale_y_continuous(labels = scales::percent) +
  theme(plot.title = element_text(hjust = 0.5)) +
  geom_text(aes(label = paste0(round(v20,2),"%"),y=labelpos),size = 3, color="white")

# 2016 Democratic County Vote Share
ggplot(mean_county, aes(fill=party, x=density, y=v16)) + 
  geom_bar(position="fill", stat="identity") +
  scale_fill_manual(values = c("blue","red")) +
  labs(title="Two Party Vote by County, 2016", x="County Type", y="Vote share", fill="Party") +
  scale_y_continuous(labels = scales::percent) +
  theme(plot.title = element_text(hjust = 0.5)) +
  geom_text(aes(label = paste0(round(v16,2),"%"),y=labelpos16),size = 3, color="white")

# 2020 Democratic Vote Shift Versus 2016 Democratic Vote Shift
ggplot(county_vote, aes(x = shift_12_16, y = shift_16_20, color = density)) + 
  geom_point() + geom_hline(yintercept = 0) + 
  geom_vline(xintercept = 0) + facet_wrap(~density) +
  labs(title="2020 Democratic Vote Shift Versus 2016 Democratic Vote Shift", x="2012-2016 Democratic Vote Shift", y= "2016-2020 Democratic Vote Shift", color="County Density") +
  theme(plot.title = element_text(hjust = 0.5)) +
  guides(color=FALSE)

# 2020 Democratic Vote Versus Vote Shift From 2016
ggplot(county_vote, aes(x = shift_16_20, y = `2020`, color = density)) + 
  geom_point() + geom_hline(yintercept = 0) + 
  geom_vline(xintercept = 0) + facet_wrap(~density) +
  labs(title="2020 Democratic Vote Versus Vote Shift From 2016", x="2016-2020 Democratic Vote Shift", y= "2020 Democratic Vote", color="County Density") +
  theme(plot.title = element_text(hjust = 0.5)) +
  guides(color=FALSE)

# 2020 Democratic Vote by County Versus 2016, Faceted
ggplot(county_vote, aes(x = `2016`, y = `2020`, color = density)) + 
  geom_point() + geom_abline() + facet_wrap(~density) +
  labs(title="2020 Democratic Vote by County Versus 2016", x="2016 Democratic Vote", y= "2020 Democratic Vote", color="County Density") +
  theme(plot.title = element_text(hjust = 0.5)) +
  guides(color=FALSE)

# 2020 Democratic Vote by County Versus 2016 (Single Chart)
ggplot(county_vote, aes(x = `2016`, y = `2020`, color = density)) + 
  geom_vline(xintercept = 0, color="gray") + 
  geom_hline(yintercept = 0, color="gray") + 
  geom_point() + geom_abline() +
  labs(title="2020 Democratic Vote by County Versus 2016", x="2016 Democratic Vote", y= "2020 Democratic Vote", color="County Density") +
  theme(plot.title = element_text(hjust = 0.5))

####### Creating Table and Regressions ############

# Filter results for urban counties
urban <-county_vote %>% 
  filter(density=="Urban")

# Filter results for suburban counties 
suburban <-county_vote %>% 
  filter(density=="Suburban")

# Filter results for rural counties
rural <-county_vote %>% 
  filter(density=="Rural")

# Run regressions on vote shift by county type
shift16 <- lm(data = county_vote, shift_16_20 ~ density)
shift20 <- lm(data = county_vote, shift_12_20 ~ density)

# Create regression table
stargazer(shift16, shift20, type = "text")

# Create vote correlation data for table
a1 <- round(cor(county_vote$`2020`, county_vote$`2016`), 3)
a2 <- round(cor(urban$`2020`, urban$`2016`), 3)
a3 <- round(cor(suburban$`2020`, suburban$`2016`), 3)
a4 <- round(cor(rural$`2020`, rural$`2016`), 3)

# Create mean vote shift data for table
b1 <- round(mean(county_vote$shift_16_20), 3)
b2 <- round(mean(urban$shift_16_20), 3)
b3 <- round(mean(suburban$shift_16_20), 3)
b4 <- round(mean(rural$shift_16_20), 3)

# Create median vote shift data for table
c1 <- round(median(county_vote$shift_16_20), 3)
c2 <- round(median(urban$shift_16_20), 3)
c3 <- round(median(suburban$shift_16_20), 3)
c4 <- round(median(rural$shift_16_20), 3)

# Create weighted mean vote shift data for table
d1 <- round(weighted.mean(county_vote$shift_16_20, county_vote$total), 3)
d2 <- round(weighted.mean(urban$shift_16_20, urban$total), 3)
d3 <- round(weighted.mean(suburban$shift_16_20, suburban$total), 3)
d4 <- round(weighted.mean(rural$shift_16_20, rural$total), 3)

# Merge table data stats together
summary_stats <- matrix(c(a1,a2,a3,a4,b1,b2,b3,b4,c1,c2,c3,c4,d1,d2,d3,d4),ncol=4,byrow=TRUE)
colnames(summary_stats) <- c("Combined Counties", "Urban Counties", "Suburban Counties", "Rural Counties")
rownames(summary_stats) <- c("Vote Correlation (2016 & 2020)", "Mean % Shift in Dem. Vote (2016-2020)", "Median % Shift in Dem. Vote (2016-2020)", "Population Weighted Mean % Shift in Dem. Vote (2016-2020)")
summary_stats <- as.table(summary_stats)
summary_stats

# Export table
write.table(summary_stats, file = "~/Downloads/plot.txt", sep=",")

###### Maps ###############

# Studied County Map
plot_usmap(data = county_vote, regions = "counties", values = "density") +
  scale_fill_manual(values = c("brown", "orange", "red"), name = "Studied Counties") +
  theme_void()

# Create map of 2016 - 2020 party vote shift by county
plot_usmap(data = county_vote, regions = "counties", values = "shift_16_20") +
  scale_fill_gradient2(low = "red", mid="white", high = "blue", midpoint = 0, name = "Vote shift from 2016 to 2020") +
  theme_void()
