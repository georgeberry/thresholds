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


# OKAY: the problem is that the error distributions aren't the same
# to fix this, we need to impose some kind of parametric solution
# that accounts for the fact that we have downwardly-biased errors
#
# the way to think about this is simple:
# the network excludes higher-threshold nodes at a higher rate
# if an individual has a higher epsilon, they have a higher chance of being excluded
#
# can we fix this with just a normality assumption for the error?
#
# Information we need: Either:
# A way to take threshold intervals and assign a value to them
# A way to infer the bias in the error term
#
# Information we have:
# 1) true thresholds for observed individuals
# 2) threshold interval for unobserved individuals
# 3) covariates for all individuals
# 4) node degree
#
# In expectation:
# b_1 x_1 + e_1 - y_1 = b_2 x_2 + e_2 - y_2
#
# we observe x_1, x_2, y_1
# we can assume b_1 = b_2 = b
# we don't observe e_1, e_2, y_2
#
# b x_1 + e_1 - y_1 = b x_2 + e_2 - y_2
# b ( x_1 - x_2 ) = e_2 - e_1 + y_1 - y_2
#
# e_2 - e_1 != 0
#
# among the observed, we'd expect x = 2 to have some nice distribution of values
# we can correct based on this informatino
library(ggplot2)
library(sampleSelection)
library(stargazer)
library(AER)
library(censReg)
library(pscl)
library(ipw)
library(dplyr)

base_path = "/Users/g/Google Drive/project-thresholds/thresholds/data/"
ws_data_file = "pl_output.csv"
ws_path = paste0(base_path, ws_data_file)

df = read.csv(ws_path)
df$threshold_ceil = ceiling(df$threshold)

observed_df = df[df$observed == 1, ]
#observed_df$after_activation_alters = observed_df$after_activation_alters - .5

sample_df = df
sample_df$sample = 0
observed_df$sample = 1
sample_df = rbind(sample_df, observed_df)

comparison_df = df[,c('var1', 'epsilon', 'threshold_ceil')]
comparison_df$sample = 0
observed_comparison_df = observed_df[,c('var1','epsilon','after_activation_alters')]
observed_comparison_df$sample = 1
observed_comparison_df$threshold_ceil = observed_comparison_df$after_activation_alters
observed_comparison_df$after_activation_alters = NULL
comparison_df = rbind(comparison_df, observed_comparison_df)

# plots for paper

ggplot(df, aes(x=threshold)) + geom_histogram(data=df[df$observed==1,], fill='blue', alpha=.2) +geom_histogram(data=df, fill='red', alpha=.2) + theme(text=element_text(size=20)) + theme(text=element_text(size=20)) + xlab("Threshold") + ylab("Count")

ggplot(comparison_df, aes(y=threshold_ceil, x=var1, color=factor(sample))) + geom_point() + geom_smooth(method=lm) + theme(text=element_text(size=20)) + scale_colour_discrete(name="", breaks=c(0, 1), labels=c("All Data", "Observed")) + ylab("Threshold") + xlab("Covariate Value")

output0 = lm(threshold ~ var1, data=df)
output1 = lm(threshold_ceil ~ var1, data=df)
output2 = lm(after_activation_alters ~ var1, data=observed_df)
output3 = tobit(after_activation_alters ~ var1,
                left = 0,
                right = Inf,
                dist = "gaussian",
                data=observed_df)
stargazer(output1, output2, output3)

ggplot(df[df$activated == 1,], aes(y=after_activation_alters, x=threshold)) + geom_point() + theme(text=element_text(size=20)) + xlab("True Threshold") + ylab("Naive Threshold Observation")

ggplot(observed_df, aes(y=after_activation_alters, x=threshold)) + geom_point() + theme(text=element_text(size=20)) + xlab("True Threshold") + ylab("Correct Observed Thresholds")

ggplot(sample_df[sample_df$activated == 1,], aes(y=after_activation_alters, x=threshold, color=factor(sample))) + geom_point(alpha=.5) + scale_colour_discrete(name="", breaks=c(0, 1), labels=c("All Data", "Observed")) + ylab("Observed Threshold") + xlab("True Threshold") + theme(text=element_text(size=20))
# prediction test 1

unobserved_df = df[df$observed == 0,]

predicted = predict(output3, unobserved_df)
predicted2 = predict(output2, unobserved_df)
predicted3 = predict(output0, df)

rmse_correct = sqrt(mean((unobserved_df$threshold - predicted)^2))
rmse_correct2 = sqrt(mean((unobserved_df$threshold - predicted2)^2))
rmse_wrong = sqrt(mean((unobserved_df$threshold - unobserved_df$after_activation_alters)^2))
rmse_ideal = sqrt(mean((df$threshold - predicted3)^2))

# prediction test 2
# rmse as we "train" on number of nodes

predict_with_k_first = function(df, k) {
  u_df = df[df$observed == 0,]
  o_df = df[df$observed == 1,] %>% arrange(activation_order)
  k_df = head(o_df, k)
  mod = lm(after_activation_alters ~ var1, data=k_df)
  predicted_vals = predict(mod, u_df)
  rmse = sqrt(mean((u_df$threshold - predicted_vals)^2))
  return(rmse)
}

pred_result_df = data.frame(k = numeric(), rmse = numeric())

for (i in 10:nrow(observed_df)) {
  rmse = predict_with_k_first(df, i)
  newrow = data.frame(k = i, rmse = rmse)
  pred_result_df = rbind(pred_result_df, newrow)
}

ggplot(pred_result_df, aes(x=k, y=rmse)) + geom_smooth(se=F) + geom_hline(aes(yintercept=rmse_wrong)) + ylab("RMSE") + xlab("Number of Training Observations") + theme(text=element_text(size=20))

# prediction test 3

predict_all_with_k_first = function(df, k) {
  u_df = df[df$observed == 0,]
  o_df = df[df$observed == 1,] %>% arrange(activation_order)
  k_df = head(o_df, k)
  mod = lm(after_activation_alters ~ var1, data=k_df)
  predicted_vals = predict(mod, df)
  rmse = sqrt(mean((df$threshold - predicted_vals)^2))
  return(rmse)
}

pred_result_df = data.frame(k = numeric(), rmse = numeric())

for (i in 10:nrow(observed_df)) {
  rmse = predict_all_with_k_first(df, i)
  newrow = data.frame(k = i, rmse = rmse)
  pred_result_df = rbind(pred_result_df, newrow)
}

ggplot(pred_result_df, aes(x=k, y=rmse)) + geom_smooth(se=F) + geom_hline(aes(yintercept=rmse_wrong)) + ylab("RMSE") + xlab("Number of Training Observations") + theme(text=element_text(size=20)) + geom_hline(aes(yintercept=rmse_ideal)) + expand_limits(x = 0, y = 0)
