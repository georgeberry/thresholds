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
# We detail how good adjustments are
#
# TODO:
#   1. Make sure we're only analyzing the adopters

library(ggplot2)
library(sampleSelection)
library(stargazer)
library(AER)
library(censReg)

base_path = "/Users/g/Google Drive/project-thresholds/thresholds/data/"

ws_data_file = "ws_output.csv"
ws_path = paste0(base_path, ws_data_file)

ws_df = read.csv(ws_path)
ws_df = ws_df[which(ws_df$activated == 1), ]
ws_df$activation_difference = ws_df$after_activation_alters - ws_df$before_activation_alters

# for testing
df = ws_df

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
  
  print(ks.test(measured$after_activation_alters, unmeasured$after_activation_alters))
  print(ks.test(measured$after_activation_alters, df$after_activation_alters))
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
# outputs a nice Stargazer model
model_comparison = function(df) {
  # the tobit procedure is appropriate for cases where we have censored data (e.g. left censored at 0)
  # tobit:
  # m = censReg(after_activation_alters ~ gender + age + race, data=ws_df[which(df$observed ==1), ])
  #
  # the heckit procedure is acceptable when we have systematic ways of selecting the observed sample
  #
  # heckit:
  # m = selection(observed ~ gender + age + race + degree, after_activation_alters ~ gender + age + race, data=ws_df)
  prob_regression = glm(observed ~ age + degree, family=binomial(link=probit), data=df)
  df$fitted = fitted(prob_regression)
  df$weights = 1/df$fitted

  observed_df = df[which(df$observed == 1),]
  
  # true thing
  print(summary(lm(threshold ~ age, data=df)))
  
  # true on observed
  print(summary(lm(threshold ~ age, data=observed_df)))
  
  # naive ols
  print(summary(lm(after_activation_alters ~ age, data=observed_df)))
  
  # tobit with weights on all data
  print(summary(tobit(
    after_activation_alters ~ age,
    left = 0,
    right = Inf,
    dist = "gaussian",
    data=df,
    weights=weights)))
  
  # tobit with weights on observed data
  m = tobit(
    after_activation_alters ~ age,
    left = 0,
    right = Inf,
    dist = "gaussian",
    data=observed_df,
    weights=weights)
  print(summary(m))
}

## Run This Shit ##

true_threshold_comparison_plot(ws_df)
ks_distribution_comparison(ws_df)


p = fitted(m)
observed_df$predicted = f

# using weights for correction
g = ggplot(observed_df, aes(x = predicted))
g + geom_histogram(binwidth=.5, alpha=.5, position="identity", aes(weights=observed_df$weights))

# scatter to see selection visually
g = ggplot(df, aes(x = age, y = threshold, color=factor(observed)))
g = g + geom_smooth(method=lm)
g + geom_point(shape=1)

summary(lm(threshold ~ age, df[df$observed==0,]))
summary(lm(threshold ~ age, df[df$observed==1,]))

g = ggplot(df, aes(x = age, y = after_activation_alters, color=factor(observed)))
g = g + geom_smooth(method=lm)
g + geom_point(shape=1)

summary(lm(after_activation_alters ~ age, df[df$observed==0,]))
summary(lm(after_activation_alters ~ age, df[df$observed==1,]))

# 

s = selection(observed ~ age, after_activation_alters ~ age, data=df)
summary(s)

df$inv_mills = invMillsRatio(glm(observed ~ age, family=binomial(link=probit), data=df))$IMR1
summary(lm(after_activation_alters ~ inv_mills, data=df[df$observed == 1,]))
