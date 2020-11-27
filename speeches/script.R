library(tidyverse)
library(quanteda)
library(dplyr)
library(wordcloud)
library(ggwordcloud)
library(wordcloud2)

# Import data
speech_df <- read_csv("campaignspeech_2019-2020.csv")

## Create corpus
speech_corpus <- corpus(speech_df, text_field = "text", docid_field = "url")

## Create tokens and filter
speech_toks <- tokens(speech_corpus, 
                      remove_punct = TRUE,
                      remove_symbols = TRUE,
                      remove_numbers = TRUE,
                      remove_url = TRUE) %>% 
  tokens_tolower() %>%
  tokens_remove(pattern=c("joe","biden","donald","trump","president","kamala","harris")) %>%
  tokens_remove(pattern=stopwords("en")) %>%
  tokens_select(min_nchar=3) %>%
  tokens_ngrams(n=2:5)

## Create dfm
speech_dfm <- dfm(speech_toks, groups = "candidate") 

# Determine most frequently used phrases
tstat_freq <- textstat_frequency(speech_dfm, groups = "candidate")

# Filter results for Trump only
trump <- tstat_freq %>%
  filter(group == "Donald Trump")

# Filter results for Biden only
biden <- tstat_freq %>%
  filter(group == "Joe Biden")

# Gather 50 most used Trump economy phrases
trump_economy <- trump %>%
  filter(str_detect(feature, "economy|economic|financial")) %>%
  head(50)

# Gather 50 most used Trump coronavirus phrases
trump_virus <- trump %>%
  filter(str_detect(feature, "virus|corona|covid")) %>%
  head(50)

# Gather 50 most used Biden economy phrases
biden_economy <- biden %>%
  filter(str_detect(feature, "economy|economic|financial")) %>%
  head(50)

# Gather 50 most used Biden coronavirus phrases
biden_virus <- biden %>%
  filter(str_detect(feature, "virus|corona|covid")) %>%
  head(50)

# Plot Trump Economy wordcloud
par(mar = c(0,0,0,0))
dev.new(width = 1000, height = 1000, unit = "px")
wordcloud(words = trump_economy$feature, freq = trump_economy$frequency, scale = c(3,.5), color = "red")

# Plot Trump Virus wordcloud
par(mar = c(0,0,0,0))
dev.new(width = 1000, height = 1000, unit = "px")
wordcloud(words = trump_virus$feature, freq = trump_virus$frequency, scale = c(4,.5), color = "red")

# Plot Biden Economy wordcloud
par(mar = c(0,0,0,0))
dev.new(width = 1000, height = 1000, unit = "px")
wordcloud(words = biden_economy$feature, freq = biden_economy$frequency, scale = c(4,.5), color = "blue")

# Plot Biden Virus wordcloud
par(mar = c(0,0,0,0))
dev.new(width = 1000, height = 1000, unit = "px")
wordcloud(words = biden_virus$feature, freq = biden_virus$frequency, scale = c(3,.25), color = "blue")


