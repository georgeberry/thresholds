library(ggplot2)
library(plotly)
library(raster)
library(scales)
library(reshape2)
library(gridExtra)
library(dplyr)

# This file takes the output of rmse_analysis.R and makes pretty plots
# Plots the following things:
#   1. One run---histogram of measured and all thresholds
#   2. One run---scatterplot of true vs measured thresholds
#   3. One run---threshold vs X value, true and correctly measured thresholds
#   4. All runs---Bar graph of number of correctly measured thresholds
#   5. All runs---Heatmap of mean RMSE at mean degree by error st.dev
#   6. All runs---RMSE at k, with baseline RMSE
#   7. All runs---Error of correctly measured cases
#   8. All runs---Beta based on correctly measured cases
#   9. All runs---Constant of correctly measured cases
#   10. All runs---RMSE true vs RMSE observed
#
# Since the rewrite of rmse_analysis, we now do aggregation here with dplyr

#### Constants ###############################################################

BASE_PATH = '/Users/g/Desktop/data/'
SIM_REP_PATH = paste(BASE_PATH, "sim_replicants/", sep="")
ONE_OFF_SIM_PATH = paste(SIM_REP_PATH, "c_5_N_N__n_3-0_0_1-0__e_N_0_0-5___12_1000_plc_0-1~7.csv", sep="")
SIM_RMSE_DF_PATH = paste(BASE_PATH, "sim_rmse_df.csv", sep="")
SIM_K_DF_PATH = paste(BASE_PATH, "sim_k_df.csv", sep="")
EMPR_REP_PATH = paste(BASE_PATH, "empirical_replicants/", sep="")
ONE_OFF_EMPR_PATH = paste(EMPR_REP_PATH, "e_N_0_12.0__c_10.0_N_N__empirical_5.0_N_N___American75_gc~3.csv")
EMPR_RMSE_DF_PATH = paste(BASE_PATH, "empirical_rmse_df.csv", sep="")
EMPR_K_DF_PATH = paste(BASE_PATH, "empirical_k_df.csv", sep="")

#### One-off analysis ########################################################

# comparison_df stacks all data (sample=0) with cm subset (sample=1)

cm_df = one_off_df[one_off_df$observed==1,]
sample_df = one_off_df
sample_df$sample = 0
cm_df$sample = 1
sample_df = rbind(sample_df, observed_df)

######## stacked distributions ###############################################
ggplot(sample_df, aes(x=threshold)) +
    geom_histogram(
        data=sample_df[sample_df$sample==0,], fill='blue', alpha=.4
    ) +
    geom_histogram(
        data=sample_df[sample_df$sample==1,], fill='red', alpha=.3
    ) +
    theme(text=element_text(size=20)) +
    theme(text=element_text(size=20)) +
    xlab("Threshold") + ylab("Count")

######## all activated vs measured thresholds ################################
# should we also do this vs all?
ggplot(sample_df[sample_df$activated==1,]) +
    aes(y=after_activation_alters, x=threshold, color=factor(sample))) +
    geom_point(alpha=.7) +
    scale_colour_discrete(name="", breaks=c(0, 1), labels=c("All Data", "Correct")) +
    ylab("Measured Threshold") +
    xlab("True Threshold") +
    theme(text=element_text(size=20)) +
    geom_abline(intercept=.5) +
    xlim(-5, 45)

######## true vs observed, regression ########################################
ggplot(sample_df) +
    aes(y=threshold_ceil, x=var1, color=factor(sample))) +
    geom_point() +
    geom_smooth(method=lm) +
    theme(text=element_text(size=20)) +
    scale_colour_discrete(name="", breaks=c(0, 1), labels=c("True Thresholds", "Correct Measured")) +
    ylab("Threshold") +
    xlab("X Value")

#### RMSE analysis ############################################################

six_colors = c(
    "deepskyblue",
    "coral",
    "dodgerblue",
    "darkorange",
    "deepskyblue4",
    "darkorange3"
)

#### for sim data #############################################################
sim_rmse_df = read.csv(SIM_RMSE_DF_PATH)
sim_rmse_df = sim_rmse_df %>%
    group_by(sim_network, constant, var1_coef, var1_sd, error_sd) %>%
    summarize(
        count = n(),
        cm_num_mean = mean(cm_num),
        cm_num_sd = sd(cm_num),
        cm_cons_mean = mean(cm_cons_ols),
        cm_beta_sd = mean(cm_cons_ols),
        cm_beta_mean = mean(cm_beta_ols),
        cm_beta_sd = sd(cm_beta_ols),
        cm_r2 = mean(cm_r2),
        cm_naive_rmse = mean(cm_naive_rmse),
        cm_rmse = mean(cm_rmse),
        active_num_mean = mean(active_num),
        active_num_sd = sd(active_num),
        active_cons_mean = mean(active_cons),
        active_beta_sd = mean(active_cons),
        active_beta_mean = mean(active_beta),
        active_beta_sd = sd(active_beta),
        active_r2 = mean(active_r2),
        active_naive_rmse = mean(active_naive_rmse),
        active_rmse = mean(active_rmse),
        true_num_mean = mean(run_num),
        true_cons_mean = mean(true_cons),
        true_beta_sd = mean(true_cons),
        true_beta_mean = mean(true_beta),
        true_beta_sd = sd(true_beta),
        true_r2 = mean(true_r2),
        true_rmse = mean(true_rmse)
    )

#### sim data analysis #######################################################

######## number correctly measured ###########################################
df_m = sim_rmse_df[,c("num_observed_mean", "graph_type", "mean_deg")]
df_m = melt(df_m, id=c("graph_type", "mean_deg"))
a_m = melt(acast(df_m, mean_deg ~ graph_type ~ variable, mean))
ggplot(a_m, aes(x=factor(Var1), y=value, fill=factor(Var2))) +
    geom_bar(stat="identity", position="dodge") +
    xlab("Mean Degree") +
    ylab("Num Correctly Measured Thresholds") +
    theme(text=element_text(size=20)) +
    ylim(0, 200) +
    scale_fill_discrete(name = "Graph Type")

######## BIAS VS VARIANCE ####################################################

############ selection on error as function of error sd ######################

ggplot(sim_rmse_df) +
    aes(
        x=error_sd,
        y=epsilon_obs_mean,
        color=interaction(graph_type, mean_deg)
    ) +
    geom_point() +
    geom_smooth(method=lm, se=FALSE) +
    scale_color_manual(values=six_colors, name="Graph Type") +
    labs(x="Error SD", "Correctly Measured Epsilon Mean")

############ coefficient bias ################################################

################ beta ########################################################

b = ggplot(sim_rmse_df)
b = b + aes(
    x=error_sd,
    y=beta_obs_mean,
    group=interaction(graph_type, mean_deg),
    color=interaction(graph_type, mean_deg)
    )
b = b + geom_point()
b = b + geom_smooth(method=lm, se=FALSE)
b = b + scale_color_manual(values=six_colors, name="Graph Type")
b = b + labs(x="Error SD", y="Beta Mean")
# constant

c = ggplot(sim_rmse_df)
c = c + aes(
    x=error_sd,
    y=cons_obs_mean,
    group=interaction(graph_type, mean_deg),
    color=interaction(graph_type, mean_deg)
    )
c = c + geom_point()
c = c + geom_smooth(method=lm, se=FALSE)
c = c + scale_color_manual(values=six_colors, guide=FALSE)
c = c + labs(x="Error SD", y="Constant Mean")

grid.arrange(c, b, ncol=2, widths=c(1, 1.15))

############ fraction of rmse that is bias vs variance #######################

ggplot(sim_rmse_df) +
    aes(x=error_sd)) +
    geom_smooth(method=lm, aes(y=rmse_obs_mean, color=factor(graph_type))) +
    geom_smooth(method=lm, aes(y=rmse_true_mean)) +
    labs(x="Error SD", "RMSE")

#### for empirical data ######################################################

empr_rmse_df = read.csv(EMPR_RMSE_DF_PATH)
empr_rmse_df = empr_rmse_df %>%
    group_by(sim_network, constant, var1_coef, error_sd) %>%
    summarize(
        count = n(),
        cm_num_mean = mean(cm_num),
        cm_num_sd = sd(cm_num),
        cm_cons_mean = mean(cm_cons_ols),
        cm_beta_sd = mean(cm_cons_ols),
        cm_beta_mean = mean(cm_beta_ols),
        cm_beta_sd = sd(cm_beta_ols),
        cm_r2 = mean(cm_r2),
        cm_naive_rmse = mean(cm_naive_rmse),
        cm_rmse = mean(cm_rmse),
        active_num_mean = mean(active_num),
        active_num_sd = sd(active_num),
        active_cons_mean = mean(active_cons),
        active_beta_sd = mean(active_cons),
        active_beta_mean = mean(active_beta),
        active_beta_sd = sd(active_beta),
        active_r2 = mean(active_r2),
        active_naive_rmse = mean(active_naive_rmse),
        active_rmse = mean(active_rmse),
        true_num_mean = mean(run_num),
        true_cons_mean = mean(true_cons),
        true_beta_sd = mean(true_cons),
        true_beta_mean = mean(true_beta),
        true_beta_sd = sd(true_beta),
        true_r2 = mean(true_r2),
        true_rmse = mean(true_rmse)
    )

#### empr rmse analysis ######################################################

######## number correctly measured ###########################################
df_m = sim_rmse_df[,c("num_observed_mean", "graph_type", "mean_deg")]
df_m = melt(df_m, id=c("graph_type", "mean_deg"))
a_m = melt(acast(df_m, mean_deg ~ graph_type ~ variable, mean))
ggplot(a_m, aes(x=factor(Var1), y=value, fill=factor(Var2))) +
    geom_bar(stat="identity", position="dodge") +
    xlab("Mean Degree") +
    ylab("Num Correctly Measured Thresholds") +
    theme(text=element_text(size=20)) +
    ylim(0, 200) +
    scale_fill_discrete(name = "Graph Type")

######## BIAS VS VARIANCE ####################################################

############ selection on error as function of error sd ######################

ggplot(sim_rmse_df) +
    aes(
        x=error_sd,
        y=epsilon_obs_mean,
        color=interaction(graph_type, mean_deg)
    ) +
    geom_point() +
    geom_smooth(method=lm, se=FALSE) +
    scale_color_manual(values=six_colors, name="Graph Type") +
    labs(x="Error SD", "Correctly Measured Epsilon Mean")

############ coefficient bias ################################################

################ beta ########################################################

b = ggplot(sim_rmse_df)
b = b + aes(
    x=error_sd,
    y=beta_obs_mean,
    group=interaction(graph_type, mean_deg),
    color=interaction(graph_type, mean_deg)
    )
b = b + geom_point()
b = b + geom_smooth(method=lm, se=FALSE)
b = b + scale_color_manual(values=six_colors, name="Graph Type")
b = b + labs(x="Error SD", y="Beta Mean")
# constant

c = ggplot(sim_rmse_df)
c = c + aes(
    x=error_sd,
    y=cons_obs_mean,
    group=interaction(graph_type, mean_deg),
    color=interaction(graph_type, mean_deg)
    )
c = c + geom_point()
c = c + geom_smooth(method=lm, se=FALSE)
c = c + scale_color_manual(values=six_colors, guide=FALSE)
c = c + labs(x="Error SD", y="Constant Mean")

grid.arrange(c, b, ncol=2, widths=c(1, 1.15))

############ fraction of rmse that is bias vs variance #######################

ggplot(sim_rmse_df) +
    aes(x=error_sd)) +
    geom_smooth(method=lm, aes(y=rmse_obs_mean, color=factor(graph_type))) +
    geom_smooth(method=lm, aes(y=rmse_true_mean)) +
    labs(x="Error SD", "RMSE")

#### K analysis ##############################################################

#### for sim data ############################################################
sim_k_df = read.csv(SIM_K_DF_PATH)
sim_k_df = sim_k_df %>%
    group_by(sim_network, constant, var1_coef, var1_sd, error_sd, k) %>%
    summarize(
        count = n(),
        rmse_at_k = mean(rmse_at_k),
        naive_rmse = mean(naive_rmse),
        true_rmse = mean(true_rmse)
    ) %>%
    filter(count > 100)

#### sim k analysis here #####################################################

ggplot(sim_k_df) +
    aes(x=k, y=rmse_obs_mean, color=factor(error_sd))) +
    geom_smooth() +
    xlab("k") +
    ylab("RMSE") +
    theme(text=element_text(size=20)) +
    scale_colour_discrete(name = "Error Std Dev")

ggplot(sim_k_df) +
    aes(x=k, y=rmse_obs_mean, color=factor(graph_type))) +
    geom_smooth() +
    xlab("k") + ylab("RMSE") +
    theme(text=element_text(size=20)) +
    scale_colour_discrete(name = "Graph Type")

#### for empirical data ######################################################

empr_k_df = read.csv(EMPR_K_DF_PATH)
empr_k_df = empr_k_df %>%
    group_by(sim_network, constant, var1_coef, error_sd, k) %>%
    summarize(
        count = n(),
        rmse_at_k = mean(rmse_at_k),
        naive_rmse = mean(naive_rmse),
        true_rmse = mean(true_rmse)
    ) %>%
    filter(count > 25)

#### empirical k analysis here ###############################################

ggplot(empr_k_df) +
    aes(x=k, y=rmse_obs_mean, color=factor(error_sd))) +
    geom_smooth() +
    xlab("k") +
    ylab("RMSE") +
    theme(text=element_text(size=20)) +
    scale_colour_discrete(name = "Error Std Dev")

ggplot(empr_k_df) +
    aes(x=k, y=rmse_obs_mean, color=factor(graph_type))) +
    geom_smooth() +
    xlab("k") + ylab("RMSE") +
    theme(text=element_text(size=20)) +
    scale_colour_discrete(name = "Graph Type")

#### old, terrible code ######################################################

one_off_df = read.csv(ONE_OFF_PATH)
rmse_df = read.csv(RMSE_DF_PATH)
k_df = read.csv(K_DF_PATH)

## one-off example plots ##


summary(lm(threshold_ceil~var1, data=observed_df))
# summary(tobit(after_activation_alters~var1, data=observed_df))

## missing-ness heatmaps ##

# might need to name columns appropriately
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

df_v = rmse_df[,c("mean_deg", "error_sd", "rmse_obs_mean")]
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
