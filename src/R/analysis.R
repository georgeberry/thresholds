# This file reads in data from our simulations
# Simulation data has one row per node
# There is a before activation and after activation observation on each line
#
# With this data, we want to do the following:
#   1. Plot threshold distributions for obseved and missing nodes
#   2. Plot threshold distributions using the p(k) curve method
#   3. Do distributional tests with Kolmogorov-Smirnov
#   4. Do regressions using OLS and Tobit
#   5. Plot the p(k) probabilty vs the true threshold probability (like Chris' dissertation)
#
# Tests should be done between the observed and the true distributions
#
# We have a nice story here: we know the truth. We compare it to what the network gives.
# We detail how good adjustments are.

library(ggplot2)
library(sampleSelection)
library(stargazer)

base_path = "/Users/g/Google Drive/project-thresholds/thresholds/data/"

ws_data_file = "ws_output.csv"
ws_path = paste0(base_path, ws_data_file)

ws_df = read.csv(ws_path)

ggplot(ws_df, aes(x=threshold, fill=factor(observed))) + geom_histogram(binwidth=.5, alpha=.5, position="identity")
ggplot(ws_df, aes(x=threshold)) + geom_histogram(binwidth=.5, position="identity")

## Functions ##

# compares distributions of observed with true
# generates a nice plot
true_threshold_comparison_plot = function(df) {
  # take df, make a new one with a new column. we want to compare ALL to just OBSERVED
  # if we do not re-append the observed, we compare OBSERVED to UNOBSERVED
  # we do this with the sample column
  new_df = df
  new_df$sample = 0
  observed_df = new_df[which(new_df$observed == 1),]
  observed_df$sample = 1
  new_df = rbind(new_df, observed_df)
  g = ggplot(new_df, aes(x = threshold, fill=factor(sample)))
  g = g + geom_histogram(binwidth=.5, alpha=.5, position="identity")
  return(g)
}

observed_threshold_comparison_plot = function(df) {
  new_df = df
  new_df$sample = 0
  observed_df = new_df[which(new_df$observed == 1),]
  observed_df$sample = 1
  new_df = rbind(new_df, observed_df)
  g = ggplot(new_df, aes(x = after_activation_alters, fill=factor(sample)))
  g = g + geom_histogram(binwidth=.5, alpha=.5, position="identity")
  return(g)
}

# uses k-s test to compare distributions
ks_distribution_comparison = function(df) {
  measured = df[which(df$observed == 1), ]
  unmeasured = df[which(df$observed == 0), ]
  print(ks.test(measured$threshold, unmeasured$threshold))
  print(ks.test(measured$threshold, df$threshold))
}

# creates "pk" style curves like in Chris' dissertation
create_pk_comparison_plot = function(df) {
  # compare, p(k), observed, true
  # for each integer k = 0, 1, 2, etc
  # p(k): number after-activation = k / number after-activation >= k
  # true distribution: number threshold = k / number threshold >= k
  # observed sample: number obs = k / number obs >= k
  max_threshold = ceiling(max(df$threshold))
  
  for (k in 1:max_threshold) {
    if (k == 0) {
      
    }
  }
}

# uses OLS and Tobit to compare with true values
# outputs a nice Stargazer model we can 
model_comparison = function(df) {
  
}

## Run This Shit ##

create_distribution_comparison_plot(ws_df)
ks_distribution_comparison(ws_df)
