library(ggplot2)
library(plotly)
library(raster)
library(scales)
library(reshape2)

setwd("/Users/g/Google Drive/project-thresholds/thresholds/src/")

ONE_OFF_PATH = "../data/replicants/__c5NNn3-001-0eN01-0__121000plc0-2_46"
RMSE_DF_PATH = "../data/rmse_df.csv"
K_DF_PATH = "../data/k_df.csv"

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

# example rmse
ex_df = df[,c("threshold_ceil", "after_activation_alters")]
ex_df$after_activation_alters[is.na(ex_df$after_activation_alters)] = 0
rmse_example_val = sqrt(mean((ex_df$threshold_ceil - ex_df$after_activation_alters)^2))

# stacked distributions
ggplot(df, aes(x=threshold)) + geom_histogram(data=df[df$observed==1,], fill='blue', alpha=.4) + geom_histogram(data=df, fill='red', alpha=.3) + theme(text=element_text(size=20)) + theme(text=element_text(size=20)) + xlab("Threshold") + ylab("Count")

# true vs measured thresholds
ggplot(sample_df[sample_df$activated == 1,], aes(y=after_activation_alters, x=threshold, color=factor(sample))) + geom_point(alpha=.7) + scale_colour_discrete(name="", breaks=c(0, 1), labels=c("All Data", "Correct")) + ylab("Measured Threshold") + xlab("True Threshold") + theme(text=element_text(size=20)) + geom_abline(intercept=.5) + xlim(-5, 45)

# true vs observed, regression
ggplot(comparison_df, aes(y=threshold_ceil, x=var1, color=factor(sample))) + geom_point() + theme(text=element_text(size=20)) + scale_colour_discrete(name="", breaks=c(0, 1), labels=c("True Thresholds", "Correct Measured")) + ylab("Threshold") + xlab("X Value") + geom_smooth(method=lm) 

## missing-ness heatmaps ##

# might need to name columns appropriately
df_m = rmse_df[,c("Mean_Observed", "graph_type", "mean_deg")]
df_m = melt(df_m, id=c("graph_type", "mean_deg"))
a_m = melt(acast(df_m, mean_deg ~ graph_type ~ variable, mean))
ggplot(a_m, aes(x=factor(Var1), y=value, fill=factor(Var2))) + geom_bar(stat="identity", position="dodge") + xlab("Mean Degree") + ylab("Num Correctly Measured Thresholds") + theme(text=element_text(size=20)) + ylim(0, 200) + scale_fill_discrete(name = "Graph Type")

#ggplot(a, aes(factor(Var1), factor(Var2), fill=value)) + geom_raster() + scale_fill_gradientn(colours=c("#C2DFFF","#E0FFFF","#E9AB17"), guide = guide_legend(title = "Observations")) + xlab("Mean Degree") + ylab("Error Std Dev") + theme(text=element_text(size=20))

# missing as function of error var, avg degree
#ggplot(df_m, aes(Name, variable)) + geom_tile(aes(fill = rescale), colour="white") + scale_fill_gradient(low="white", high="steelblue")

## error var vs mean degree heatmap ##

df_v = rmse_df[,c("mean_deg", "error_sd", "Mean_RMSE_OLS")]
df_v = melt(df_v, id=c("error_sd", "mean_deg"))
a = melt(acast(df_v, mean_deg ~ error_sd ~ variable, mean))
#a_df = as.data.frame(a)[4:1,]
#colnames(a_df) = c("0.5", "0.8", "1", "1.5", "2")
#rownames(a_df) = c("20", "16", "12", "8")
#d3heatmap(a_df, dendrogram="none", colors="YlOrRd")
ggplot(a, aes(factor(Var1), factor(Var2), fill=value)) + geom_raster() + scale_fill_gradientn(colours=c("#82CAFA","#FFFFFF","#FBB917"), guide = guide_legend(title = "RMSE")) + xlab("Mean Degree") + ylab("Error Std Dev") + theme(text=element_text(size=20))

## plots of rmse rates by k ##

## rmse rates by k and error variance ##

# ggplot(k_df, aes(x=k, y=mean_rmse, color=id_col)) + geom_smooth(aes(ymin=mean_rmse - sd_rmse, ymax=mean_rmse + sd_rmse))

#ggplot(rmse_df, aes(Mean_RMSE_OLS, id_col)) + geom_tile(aes(fill=))

# can aggregate across various graph types
# by graph type / error var
ggplot(k_df, aes(x=k, y=mean_rmse, color=factor(error_sd))) + geom_smooth(aes(ymin=mean_rmse - sd_rmse, ymax=mean_rmse + sd_rmse)) + xlab("k") + ylab("RMSE") + theme(text=element_text(size=20)) + scale_colour_discrete(name = "Error Std Dev") + geom_hline(aes(yintercept=rmse_example_val))

ggplot(k_df, aes(x=k, y=mean_rmse, color=factor(graph_type))) + geom_smooth(aes(ymin=mean_rmse - sd_rmse, ymax=mean_rmse + sd_rmse)) + xlab("k") + ylab("RMSE") + theme(text=element_text(size=20)) + scale_colour_discrete(name = "Graph Type") + geom_hline(aes(yintercept=rmse_example_val)) + ylim(0,8)

