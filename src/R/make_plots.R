library(ggplot2)
library(plotly)
library(raster)
library(scales)
library(reshape2)

# This file takes the output of rmse_analysis.R and makes pretty plots
# Plots the following things:
#   1. One run---histogram of measured and all thresholds
#   2. One run---scatterplot of true vs measured thresholds
#   3. One run---threshold vs X value, true and correctly measured thresholds
#   4. All runs---Bar graph of number of correctly measured thresholds
#   5. All runs---Heatmap of mean RMSE at mean degree by error st.dev
#   6. All runs---RMSE at k
#   7. All runs---Error of correctly measured cases
#   8. All runs---Beta based on correctly measured cases
#   9. All runs---Constant of correctly measured cases
#   10. All runs---RMSE true vs RMSE observed

setwd("/Users/g/Google Drive/project-thresholds/thresholds/src/R/")
ONE_OFF_PATH = "../../data/replicants/c_5_N_N__n_3-0_0_1-0__e_N_0_2-0___20_1000_pl_0-1~94"
RMSE_DF_PATH = "../../data/rmse_df.csv"
K_DF_PATH = "../../data/k_df.csv"
one_off_df = read.csv(ONE_OFF_PATH)
rmse_df = read.csv(RMSE_DF_PATH)
k_df = read.csv(K_DF_PATH)

## one-off example plots ##
df = one_off_df
df$threshold_ceil = ceiling(df$threshold)
comparison_df = df[,c('var1', 'epsilon', 'threshold_ceil')]
comparison_df$sample = 0
observed_comparison_df = df[df$observed == 1,c('var1','epsilon','after_activation_alters')]
observed_comparison_df$sample = 1
observed_comparison_df$threshold_ceil = observed_comparison_df$after_activation_alters
observed_comparison_df$after_activation_alters = NULL
comparison_df = rbind(comparison_df, observed_comparison_df)

observed_df = df[df$observed == 1, ]
sample_df = df
sample_df$sample = 0
observed_df$sample = 1
sample_df = rbind(sample_df, observed_df)

# stacked distributions
ggplot(df, aes(x=threshold)) +
    geom_histogram(data=df[df$observed==1,], fill='blue', alpha=.4) +
    geom_histogram(data=df, fill='red', alpha=.3) +
    theme(text=element_text(size=20)) +
    theme(text=element_text(size=20)) +
    xlab("Threshold") + ylab("Count")

# true vs measured thresholds
ggplot(sample_df[sample_df$activated == 1,], aes(y=after_activation_alters, x=threshold, color=factor(sample))) +
    geom_point(alpha=.7) +
    scale_colour_discrete(name="", breaks=c(0, 1), labels=c("All Data", "Correct")) +
    ylab("Measured Threshold") +
    xlab("True Threshold") +
    theme(text=element_text(size=20)) +
    geom_abline(intercept=.5) +
    xlim(-5, 45)

# true vs observed, regression
ggplot(comparison_df, aes(y=threshold_ceil, x=var1, color=factor(sample))) +
    geom_point() +
    theme(text=element_text(size=20)) +
    scale_colour_discrete(name="", breaks=c(0, 1), labels=c("True Thresholds", "Correct Measured")) +
    ylab("Threshold") +
    xlab("X Value") +
    geom_smooth(method=lm)

summary(lm(threshold_ceil~var1, data=observed_df))
# summary(tobit(after_activation_alters~var1, data=observed_df))

## missing-ness heatmaps ##

# might need to name columns appropriately
df_m = rmse_df[,c("num_observed_mean", "graph_type", "mean_deg")]
df_m = melt(df_m, id=c("graph_type", "mean_deg"))
a_m = melt(acast(df_m, mean_deg ~ graph_type ~ variable, mean))
ggplot(a_m, aes(x=factor(Var1), y=value, fill=factor(Var2))) +
    geom_bar(stat="identity", position="dodge") +
    xlab("Mean Degree") +
    ylab("Num Correctly Measured Thresholds") +
    theme(text=element_text(size=20)) +
    ylim(0, 200) +
    scale_fill_discrete(name = "Graph Type")

ggplot(a_m, aes(factor(Var1), factor(Var2), fill=value)) +
    geom_raster() +
    scale_fill_gradientn(colours=c("#C2DFFF","#E0FFFF","#E9AB17"), guide = guide_legend(title = "Observations")) +
    xlab("Mean Degree") +
    ylab("Error Std Dev") +
    theme(text=element_text(size=20))

# missing as function of error var, avg degree
ggplot(df_m, aes(Name, variable)) +
    geom_tile(aes(fill = rescale), colour="white") +
    scale_fill_gradient(low="white", high="steelblue")

## error var vs mean degree heatmap ##

df_v = rmse_df[,c("mean_deg", "error_sd", "rmse_obs_mean_obs")]
df_v = melt(df_v, id=c("error_sd", "mean_deg"))
a = melt(acast(df_v, mean_deg ~ error_sd ~ variable, mean))
ggplot(a, aes(factor(Var1), factor(Var2), fill=value)) +
    geom_raster() +
    scale_fill_gradientn(colours=c("#82CAFA","#FFFFFF","#FBB917"), guide = guide_legend(title = "RMSE")) +
    xlab("Mean Degree") +
    ylab("Error Std Dev") +
    theme(text=element_text(size=20))

## plots of rmse rates by k ##

## rmse rates by k and error variance ##

# ggplot(k_df, aes(x=k, y=rmse_obs_mean, color=id_col)) +
#    geom_smooth(aes(ymin=rmse_obs_mean - rmse_obs_sd, ymax=rmse_obs_mean + rmse_obs_sd))

#ggplot(rmse_df, aes(rmse_obs_mean_OLS, id_col)) +
#    geom_tile(aes(fill=))

# can aggregate across various graph types
# by graph type / error var

# need rmse at k relative to the naive and ideal rmse

ggplot(k_df, aes(x=k, y=rmse_obs_mean, color=factor(error_sd))) +
    geom_smooth(aes(ymin=rmse_obs_mean - rmse_obs_sd, ymax=rmse_obs_mean + rmse_obs_sd)) +
    xlab("k") +
    ylab("RMSE") +
    theme(text=element_text(size=20)) +
    scale_colour_discrete(name = "Error Std Dev")

ggplot(k_df, aes(x=k, y=rmse_obs_mean, color=factor(graph_type))) +
    geom_smooth(aes(ymin=rmse_obs_mean - rmse_obs_sd, ymax=rmse_obs_mean + rmse_obs_sd)) +
    xlab("k") + ylab("RMSE") +
    theme(text=element_text(size=20)) +
    scale_colour_discrete(name = "Graph Type")


## BIAS VS VARIANCE ##

# plot selection on error as function of error sd #

ggplot(rmse_df, aes(x=error_sd, y=epsilon_obs_mean, group=factor(graph_type))) +
    geom_point() +
    geom_smooth(method=lm, se=FALSE)

# coefficient bias #

# beta

ggplot(rmse_df, aes(x=error_sd, y=beta_obs_mean, group=interaction(graph_type, mean_deg), color=interaction(graph_type, mean_deg))) +
    geom_point() +
    geom_smooth(method=lm, se=FALSE)

# constant

ggplot(rmse_df, aes(x=error_sd, y=cons_obs_mean, group=interaction(graph_type, mean_deg), color=interaction(graph_type, mean_deg))) +
    geom_point() +
    geom_smooth(method=lm, se=FALSE)

# fraction of rmse that is bias vs variance

ggplot(rmse_df, aes(x=error_sd)) +
    geom_smooth(method=lm, aes(y=rmse_obs_mean, color=factor(graph_type))) +
    geom_smooth(method=lm, aes(y=rmse_true_mean))
