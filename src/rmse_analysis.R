# This file takes our replicated runs
# Does modeling, and summarizes the results
# This produces two aggregated CSV files that form the basis of our anlaysis

# we want to get all the filenames, and strip
library(stringr)
library(dplyr)
library(AER)
library(ggplot2)
library(reshape2)

## String parsing functions ##
SimplifyFiles = function(file_vector){
    simplified_files = c()
    for (f in file_vector){
        f_simple = SimpleFilename(f)
        simplified_files = union(simplified_files, c(f_simple))
    }
    return(simplified_files)
}

# strips the number of the run
SimpleFilename = function(filename){
    s = str_split(filename, "~")
    s = s[[1]][1]
    return(s)
}

# all reps in a batch
GetAllRuns = function(batch_name){
    f_template = paste("../data/replicants/", batch_name, "*", sep="")
    return(Sys.glob(f_template))
}

ParseParams = function(batch_name){
    sections = str_split(batch_name, "___")[[1]]
    eq = ParseEqString(sections[1])
    g = ParseGraphString(sections[2])
    res = cbind(eq, g)
    return(res)
}

ParseEqString = function(eq_str){
    eq = str_split(eq_str, "__")[[1]]
    df = data.frame(constant = NA, error_sd = NA, var1_coef = NA, var1_sd = NA)
    for (idx in 1:length(eq)){
        param = str_split(eq[idx], "_")[[1]]
        # order ['distribution', 'coefficient', 'mean', 'sd']
        distribution = param[1]
        coefficient = param[2]
        m = param[3]
        s = param[4]
        if (distribution == "c") {
            df$constant = as.numeric(coefficient)
        } else if (distribution == "e") {
            df$error_sd = as.numeric(str_replace(s, "-", "."))
        } else {
            df$var1_coef = as.numeric(str_replace(coefficient, "-", "."))
            df$var1_sd = as.numeric(str_replace(s, "-", "."))
        }
    }
    return(df)
}

ParseGraphString = function(g_str){
    # hacky, but if 2nd char is a 0, then we know the first 2 are mean degree
    g_spl = str_split(g_str, "_")[[1]]
    md = as.numeric(g_spl[1])
    gs = as.numeric(g_spl[2])
    graph_type = g_spl[3]
    if (length(g_spl) == 4) {
        graph_param = as.numeric(str_replace(g_spl[4], "-", "."))
    } else {
        graph_param = NA
    }
    df = data.frame(graph_param = graph_param, mean_deg = md, graph_size = gs, graph_type = graph_type)
    print(df)
    return(df)
}

## rmse fns ##

CalcRmse = function(true_y, pred_y){
    rmse = sqrt(mean((true_y - pred_y)^2))
    return(rmse)
}

# gives imporant params + RMSE for one batch
RmseOLS = function(formula, df){
    observed_df = df[df$observed == 1,]
    mod_obs = lm(after_activation_alters ~ var1, data=observed_df)
    rmse_obs = CalcRmse(df$threshold, predict(mod_obs, df))
    mod_true = lm(threshold ~ var1, data=df)
    rmse_true = CalcRmse(df$threshold, predict(mod_true, df))
    coefs = coef(mod_obs)
    return(list("rmse_obs" = rmse_obs, "rmse_true" = rmse_true, "observed_epsilon" = observed_df$epsilon, "cons_obs" = coefs[1], "beta_obs" = coefs[2]))
}

#RmseTobit = function(formula, df, y){
#     # need to use this fuckit operator
#    observed_df <<- df[df$observed == 1,]
#    mod = tobit(formula=formula, left=0, right=Inf, data=observed_df)
#    rmse = CalcRmse(y, predict(mod, df))
#    return(rmse)
#}

# can create a param + rmse line here, with rmse variance
BatchRmse = function(all_batch_files, formula){
    rmse_df = data.frame(rmse_obs = numeric(0), epsilon_mean_obs = numeric(0), cons_obs = numeric(0), beta_obs = numeric(0), rmse_true = numeric(0), num_observed = numeric(0))
    for (f in all_batch_files){
        df = read.csv(f)
        if (sum(df$observed) < 20){
            next
        }
        df$after_activation_alters = df$after_activation_alters - .5
        rmse_list = RmseOLS(formula, df)
        rmse_obs = rmse_list$rmse_obs
        rmse_true = rmse_list$rmse_true
        cons_obs = rmse_list$cons_obs
        beta_obs = rmse_list$beta_obs
        epsilon_mean_obs = mean(rmse_list$observed_epsilon)
        rmse_df = rbind(rmse_df, data.frame(rmse_obs = rmse_obs, epsilon_mean_obs = epsilon_mean_obs, cons_obs = cons_obs, beta_obs = beta_obs, rmse_true = rmse_true, num_observed = sum(df$observed)))
    }
    means = apply(rmse_df, 2, mean)
    names(means) = c("mean_rmse_obs", "epsilon_mean_obs", "cons_mean_obs", "beta_mean_obs", "mean_rmse_true", "mean_num_observed")
    means = data.frame(as.list(means))
    sds = apply(rmse_df, 2, sd)
    names(sds) = c("sd_rmse_obs", "sd_obs_epsilon", "cons_mean_sd", "beta_mean_sd", "sd_rmse_true", "sd_num_observed")
    sds = data.frame(as.list(sds))
    return(cbind(means, sds))
}

# gives RMSE at number obs (maybe every 10?)
RmseAtKObs = function(formula, df, y){
    rmse_at_k_df = data.frame(k=numeric(0), rmse_OLS=numeric(0), cons_obs=numeric(0), beta_obs=numeric(0))
    o_df = df[df$observed == 1,] %>% arrange(activation_order)
    k_seq = seq(10, nrow(o_df), 10)
    for (k in k_seq){
        k_df = head(o_df, k)
        mod = lm(formula, data=k_df)
        rmse_at_k = CalcRmse(y, predict(mod, df))
        coefs = coef(mod)
        rmse_at_k_df = rbind(rmse_at_k_df, data.frame(k=k, rmse_OLS=rmse_at_k, cons_obs=coefs[1], beta_obs=coefs[2]))
    }
    return(rmse_at_k_df)
}

# want to summarize the 100 runs at k obs in a df
# can do my own sd at each k val
# output: df where cols are mean/SE
#           rows are vals of k
BatchRmseAtK = function(all_batch_files, formula){
    rmse_at_k_df = data.frame(k=numeric(0), rmse_OLS=numeric(0), cons_obs=numeric(0), beta_obs=numeric(0), rmse_true=numeric(0))
    for (f in all_batch_files){
        df = read.csv(f)
        if (sum(df$observed) < 10){
            next
        }
        df$after_activation_alters = df$after_activation_alters - .5
        df$threshold = ceiling(df$threshold)
        rmse_at_k = RmseAtKObs(formula, df, df$threshold)
        mod_true = lm(threshold ~ var1, data=df)
        rmse_at_k$rmse_true = CalcRmse(df$threshold, predict(mod_true, df))
        rmse_at_k_df = rbind(rmse_at_k_df, rmse_at_k)
    }
    summary_df = rmse_at_k_df %>%
        group_by(k) %>%
        summarize(mean_rmse=mean(rmse_OLS), sd_rmse=sd(rmse_OLS), cons_obs=mean(cons_obs), beta_obs=mean(beta_obs), cons_sd=sd(cons_obs), beta_sd=sd(beta_obs), rmse_true=mean(rmse_true), n=n())
    return(summary_df)
}

## Batch processing functions ##

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
    rmse_df$mean_deg = param_df$mean_deg
    rmse_df$graph_param = param_df$graph_param
    rmse_df$id_col = paste(rmse_df$graph_type, rmse_df$graph_size, rmse_df$error_sd, rmse_df$mean_deg, rmse_df$graph_param)
    rmse_at_k_df$graph_type = param_df$graph_type
    rmse_at_k_df$graph_size = param_df$graph_size
    rmse_at_k_df$error_sd = param_df$error_sd
    rmse_at_k_df$mean_deg = param_df$mean_deg
    rmse_at_k_df$graph_param = param_df$graph_param
    rmse_at_k_df$id_col = paste(rmse_at_k_df$graph_type, rmse_at_k_df$graph_size, rmse_at_k_df$error_sd, rmse_at_k_df$mean_deg, rmse_at_k_df$graph_param)
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

## Run script ##

# plot fns #
setwd('/Users/g/Google Drive/project-thresholds/thresholds/src/')
## Prep Files ##
DATA_PATH = "../data/replicants/"
all_files = list.files(DATA_PATH)
all_batches = SimplifyFiles(all_files)

print(all_batches)
## Analyze ##
r = ProcessAllBatches(all_batches)
k_df = r$k_df
rmse_df = r$rmse_df

write.csv(k_df, "../data/k_df.csv")
write.csv(rmse_df, "../data/rmse_df.csv")
