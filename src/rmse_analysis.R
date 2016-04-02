# This file does RMSE analysis
# It generates two plots
#   1) RMSE vs error as fraction of r^2 (violin or boxplot)
#   2) RMSE as function of # training obs for various params
#
# The challenge here is how to deal with reps (computationally)
# Each param set will have its own folder
# We can read an entire folder, do the analysis, and then avg results
# For instance, for box in plot 1), we'll have 100 RMSE obs
# For plot 2), we'll have 100 obs for each X val for each param set
#   This is a lot, is there an easy way to draw the error bars?

# we want to get all the filenames, and strip
library(stringr)
library(dplyr)
library(AER)
library(ggplot2)

# strips the number of the run
SimpleFilename = function(filename){
    s = str_replace_all(filename, "__", "~")
    s = str_split(s, "_")
    s = s[[1]][1]
    s = str_replace_all(s, "~", "__")
    return(s)
}

# simplifies all files
SimplifyFiles = function(file_vector){
    simplified_files = c()
    for (f in file_vector){
        f_simple = SimpleFilename(f)
        simplified_files = union(simplified_files, c(f_simple))
    }
    return(simplified_files)
}

# all reps in a batch
GetAllRuns = function(batch_name){
    f_template = paste("../data/", batch_name, "*", sep="")
    return(Sys.glob(f_template))
}

ParseParams = function(batch_name){
    sections = str_split(batch_name, "__")[[1]]
    eq = ParseEqString(sections[2])
    g = ParseGraphString(sections[3])
    res = cbind(eq, g)
    return(res)
}

ParseEqString = function(eq_str){
    eq = str_split(eq_str, "[cne]")[[1]]
    eq = eq[2:length(eq)]
    df = data.frame(constant = NA)
    for (idx in 1:length(eq)){
        param = eq[idx]
        # constant
        if (idx == 1) {
            constant = as.numeric(substr(param, 1, 1))
            df$constant = constant
        }
        # error
        else if (idx == length(eq)) {
            error_sd_str = str_replace(substr(param, 3, 5), "-", ".")
            error_sd = as.numeric(error_sd_str)
            df$error_sd = error_sd
        }
        # everything else
        else {
            coefficient = as.numeric(str_replace(substr(param, 1, 3), "-", "."))
            sd = as.numeric(str_replace(substr(param, 5, 7), "-", "."))
            if ("var1_coef" %in% colnames(df)){
                df$var2_coef = coefficient
                df$var2_sd = sd
            } else {
                df$var1_coef = coefficient
                df$var1_sd = sd
            }
        }
    }
    return(df)
}

ParseGraphString = function(g_str){
    # hacky, but if 2nd char is a 0, then we know the first 2 are mean degree
    graph_type = str_replace_all(g_str, "([:digit:]|[:punct:])", "")
    g_spl = str_split(g_str, "[:alpha:]+")[[1]]
    size = g_spl[1]
    param = as.numeric(str_replace(g_spl[2], "-", "."))
    if (substr(size, 2, 2) == "0") {
        md = as.numeric(substr(size, 1, 2))
        gs = as.numeric(substr(size, 3, nchar(size)))
    } else {
        md = as.numeric(substr(size, 1, 1))
        gs = as.numeric(substr(size, 2, nchar(size)))
    }
    df = data.frame(graph_param = param, mean_deg = md, graph_size = gs, graph_type = graph_type)
    return(df)
}


## rmse fns ##

CalcRmse = function(true_y, pred_y){
    rmse = sqrt(mean((true_y - pred_y)^2))
    return(rmse)
}

# gives imporant params + RMSE for one batch
RmseOLS = function(formula, df, y){
    observed_df = df[df$observed == 1,]
    mod = lm(formula, data=observed_df)
    rmse = CalcRmse(y, predict(mod, df))
    return(rmse)
}

RmseTobit = function(formula, df, y){
    observed_df = df[df$observed == 1,]
    mod = tobit(formula=formula, left=0, right=Inf, data=observed_df)
    rmse = CalcRmse(y, predict(mod, df))
    return(rmse)
}

# can create a param + rmse line here, with rmse variance
BatchRmse = function(all_batch_files, formula){
    rmse_df = data.frame(rmse_ols = numeric(0), rmse_tobit = numeric(0))
    for (f in all_batch_files){
        df = read.csv(f)
        if (sum(df$observed) < 10){
            next
        }
        df$after_activation_alters = df$after_activation_alters - .5
        df$threshold = ceiling(df$threshold)
        rmse_ols = RmseOLS(formula, df, df$threshold)
        rmse_tobit = 1
        #rmse_tobit = RmseTobit(formula, df, df$threshold)
        rmse_df = rbind(rmse_df, data.frame(rmse_ols = rmse_ols, rmse_tobit = rmse_tobit))
    }
    means = apply(rmse_df, 2, mean)
    names(means) = c("Mean_RMSE_OLS", "Mean_RMSE_Tobit")
    means = data.frame(as.list(means))
    ses = apply(rmse_df, 2, sd) / sqrt(nrow(rmse_df))
    names(ses) = c("SE_RMSE_OLS", "SE_RMSE_Tobit")
    ses = data.frame(as.list(ses))
    return(cbind(means, ses))
}

# gives RMSE at number obs (maybe every 10?)
RmseAtKObs = function(formula, df, y){
    rmse_at_k_df = data.frame(k=numeric(0), rmse_OLS=numeric(0))
    o_df = df[df$observed == 1,] %>% arrange(activation_order)
    k_seq = seq(10, nrow(o_df), 10)
    for (k in k_seq){
        k_df = head(o_df, k)
        mod = lm(formula, data=k_df)
        rmse_at_k = CalcRmse(y, predict(mod, df))
        rmse_at_k_df = rbind(rmse_at_k_df, data.frame(k=k, rmse_OLS=rmse_at_k))
    }
    return(rmse_at_k_df)
}

# want to summarize the 100 runs at k obs in a df
# can do my own sd at each k val
# output: df where cols are mean/SE
#           rows are vals of k
BatchRmseAtK = function(all_batch_files, formula){
    rmse_at_k_df = data.frame(k=numeric(0), rmse_OLS=numeric(0))
    for (f in all_batch_files){
        df = read.csv(f)
        if (sum(df$observed) < 10){
            next
        }
        df$after_activation_alters = df$after_activation_alters - .5
        df$threshold = ceiling(df$threshold)
        rmse_at_k = RmseAtKObs(formula, df, df$threshold)
        rmse_at_k_df = rbind(rmse_at_k_df, rmse_at_k)
    }
    summary_df = rmse_at_k_df %>%
        group_by(k) %>%
        summarize(mean_rmse=mean(rmse_OLS), sd_rmse=sd(rmse_OLS), n=n()) %>%
        mutate(se_rmse = sd_rmse / sqrt(n))
    return(summary_df)
}

# attach all params to the other two output dfs
ProcessBatch = function(batch_name){
    param_df = ParseParams(batch_name)
    all_batch_files = GetAllRuns(batch_name)
    rmse_df = BatchRmse(all_batch_files, after_activation_alters~var1)
    rmse_at_k_df = BatchRmseAtK(all_batch_files, after_activation_alters~var1)
    # add params
    rmse_df$graph_type = param_df$graph_type
    rmse_df$graph_size = param_df$graph_size
    rmse_df$error_sd = param_df$error_sd
    rmse_at_k_df$graph_type = param_df$graph_type
    rmse_at_k_df$graph_size = param_df$graph_size
    rmse_at_k_df$error_sd = param_df$error_sd
    return_list = list(rmse_df = rmse_df, rmse_at_k_df = rmse_at_k_df)
    return(return_list)
}

ProcessAllBatches = function(all_batches){
    param_df = NULL
    rmse_df = NULL
    k_df = NULL
    for (b in all_batches){
        if (nchar(b) > 20){
            r = ProcessBatch(b)
            batch_rmse_df = r$rmse_df
            batch_k_df = r$rmse_at_k_df
            batch_params = r$params
            if (is.null(rmse_df)){
                rmse_df = batch_rmse_df
            } else {
                rmse_df = rbind(rmse_df, batch_rmse_df)
            }
            if (is.null(k_df)){
                k_df = batch_k_df
            } else {
                k_df = rbind(k_df, batch_k_df)
            }
        }
    }
    return(list(k_df=k_df, rmse_df=rmse_df))
}

# plot fns #
setwd('/Users/g/Google Drive/project-thresholds/thresholds/src/')
## Prep Files ##
DATA_PATH = "../data/"
all_files = list.files(DATA_PATH)
all_batches = SimplifyFiles(all_files)

## Analyze ##
r = ProcessAllBatches(all_batches)
k_df = r$k_df
rmse_df = r$rmse_df

#ggplot(k_df, aes(x=k, y=mean_rmse)) + geom_smooth()
