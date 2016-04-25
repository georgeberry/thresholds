# This file takes our replicated runs
# Does modeling, and summarizes the results
# This produces two aggregated CSV files that form the basis of our anlaysis

# we want to get all the filenames, and strip
library(stringr)
library(dplyr)
library(glmnet)
# library(AER)
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
RmseOLS = function(df){
    observed_df = df[df$observed == 1,]
    observed_df$after_activation_alters = observed_df$after_activation_alters - .5
    # regression for the observed subset
    mod_obs = lm(after_activation_alters ~ var1, data=observed_df)
    rmse_obs = CalcRmse(df$threshold, predict(mod_obs, df))
    # regression for the true model on all data
    mod_true = lm(threshold ~ var1, data=df)
    rmse_true = CalcRmse(df$threshold, predict(mod_true, df))
    coefs_obs = coef(mod_obs)
    coefs_true = coef(mod_true)
    return(list(
        "rmse_obs" = rmse_obs,
        "rmse_true" = rmse_true,
        "epsilon_obs" = observed_df$epsilon,
        "cons_obs" = coefs[1],
        "beta_obs" = coefs[2],
        "cons_true" = coefs_true[1],
        "beta_true" = coefs_true[2]
        )
    )
}

#RmseTobit = function(formula, df, y){
#     # need to use this fuckit operator
#    observed_df <<- df[df$observed == 1,]
#    mod = tobit(formula=formula, left=0, right=Inf, data=observed_df)
#    rmse = CalcRmse(y, predict(mod, df))
#    return(rmse)
#}

# can create a param + rmse line here, with rmse variance
BatchRmse = function(all_batch_files){
    rmse_df = data.frame(
        rmse_obs = numeric(0),
        epsilon_obs_mean = numeric(0),
        cons_obs = numeric(0),
        beta_obs = numeric(0),
        cons_true = numeric(0),
        beta_true = numeric(0),
        rmse_true = numeric(0),
        num_observed = numeric(0),
        rmse_naive = numeric(0)
    )
    for (f in all_batch_files){
        df = read.csv(f)
        if (sum(df$observed) < 10){
            next
        }
        rmse_list = RmseOLS(df)
        rmse_obs = rmse_list$rmse_obs
        rmse_true = rmse_list$rmse_true
        cons_obs = rmse_list$cons_obs
        beta_obs = rmse_list$beta_obs
        cons_true = rmse_list$cons_true
        beta_obs = rmse_list$beta_obs
        rmse_naive = CalcRmse(df$after_activation_alters, df$threshold)
        epsilon_obs_mean = mean(rmse_list$epsilon_obs)
        rmse_df = rbind(
            rmse_df,
            data.frame(
                rmse_obs = rmse_obs,
                epsilon_obs_mean = epsilon_obs_mean,
                cons_obs = cons_obs,
                beta_obs = beta_obs,
                cons_true = cons_true,
                beta_true = beta_true,
                rmse_true = rmse_true,
                num_observed = sum(df$observed),
                rmse_naive = rmse_naive
            )
        )
    }
    means = apply(rmse_df, 2, mean)
    names(means) = c(
        "rmse_obs_mean",
        "epsilon_obs_mean",
        "cons_obs_mean",
        "beta_obs_mean",
        "cons_true_mean",
        "beta_true_mean",
        "rmse_true_mean",
        "num_observed_mean",
        "rmse_naive_mean"
    )
    means = data.frame(as.list(means))
    sds = apply(rmse_df, 2, sd)
    names(sds) = c(
        "rmse_obs_sd",
        "obs_epsilon_sd",
        "cons_mean_sd",
        "beta_mean_sd",
        "cons_true_sd",
        "beta_true_sd",
        "rmse_true_sd",
        "num_observed_sd",
        "rmse_naive_sd"
    )
    sds = data.frame(as.list(sds))
    return(cbind(means, sds))
}

# gives RMSE at every 10 obs
RmseAtKObs = function(df){
    rmse_at_k_df = data.frame(
        k=numeric(0),
        rmse_obs=numeric(0),
        rmse_true=numeric(0),
        cons_obs=numeric(0),
        beta_obs=numeric(0)
    )
    y = df$threshold # true value
    o_df = df[df$observed == 1,] %>% arrange(activation_order)
    k_seq = seq(10, nrow(o_df), 10)
    for (k in k_seq){
        k_df = head(o_df, k)
        k_df$after_activation_alters = k$df_after_activation_alters - .5
        mod_obs = lm(after_activation_alters ~ var1, data=k_df)
        rmse_at_k = CalcRmse(y, predict(mod_obs, df))
        coefs_obs = coef(mod_obs)
        mod_true = lm(threshold ~ var1, data=df)
        rmse_true = CalcRmse(df$threshold, predict(mod_true, df))
        rmse_at_k_df = rbind(
            rmse_at_k_df,
            data.frame(
                k = k,
                rmse_obs = rmse_at_k,
                rmse_true = rmse_true,
                cons_obs = coefs_obs[1],
                beta_obs = coefs_obs[2]
            )
        )
    }
    return(rmse_at_k_df)
}

# want to summarize the 100 runs at k obs in a df
# can do my own sd at each k val
# output: df where cols are mean/SE
#           rows are vals of k
BatchRmseAtK = function(all_batch_files){
    rmse_at_k_df = data.frame(
        k=numeric(0),
        rmse_obs=numeric(0),
        cons_obs=numeric(0),
        beta_obs=numeric(0),
        rmse_true=numeric(0)
    )
    for (f in all_batch_files){
        df = read.csv(f)
        if (sum(df$observed) < 10){
            next
        }
        # df$threshold = ceiling(df$threshold)
        rmse_at_k = RmseAtKObs(df)
        rmse_at_k_df = rbind(rmse_at_k_df, rmse_at_k)
    }
    summary_df = rmse_at_k_df %>%
        group_by(k) %>%
        summarize(
            rmse_obs_mean = mean(rmse_obs),
            rmse_obs_sd = sd(rmse_obs),
            cons_obs_mean = mean(cons_obs),
            beta_obs_mean = mean(beta_obs),
            cons_true_mean = mean(cons_true),
            beta_true_mean = mean(beta_true),
            cons_obs_sd = sd(cons_obs),
            beta_obs_sd = sd(beta_obs),
            cons_true_sd = sd(cons_true),
            beta_true_sd = sd(beta_true),
            rmse_true_mean = mean(rmse_true),
            rmse_true_sd = sd(rmse_true),
            n = n()
        )
    return(summary_df)
}

## Batch processing functions ##

ProcessBatch = function(batch_name){
    param_df = ParseParams(batch_name)
    all_batch_files = GetAllRuns(batch_name)
    rmse_df = BatchRmse(all_batch_files)
    rmse_at_k_df = BatchRmseAtK(all_batch_files)
    # add params to both dfs
    ## add to rmse_df
    rmse_df$graph_type = param_df$graph_type
    rmse_df$graph_size = param_df$graph_size
    rmse_df$error_sd = param_df$error_sd
    rmse_df$mean_deg = param_df$mean_deg
    rmse_df$graph_param = param_df$graph_param
    rmse_df$id_col = paste(
        rmse_df$graph_type,
        rmse_df$graph_size,
        rmse_df$error_sd,
        rmse_df$mean_deg,
        rmse_df$graph_param
    )
    ## add to rmse_at_k_df
    rmse_at_k_df$graph_type = param_df$graph_type
    rmse_at_k_df$graph_size = param_df$graph_size
    rmse_at_k_df$error_sd = param_df$error_sd
    rmse_at_k_df$mean_deg = param_df$mean_deg
    rmse_at_k_df$graph_param = param_df$graph_param
    rmse_at_k_df$id_col = paste(
        rmse_at_k_df$graph_type,
        rmse_at_k_df$graph_size,
        rmse_at_k_df$error_sd,
        rmse_at_k_df$mean_deg,
        rmse_at_k_df$graph_param
    )
    # make list of return params
    return_list = list(rmse_df = rmse_df, rmse_at_k_df = rmse_at_k_df)
    return(return_list)
}

ProcessAllBatches = function(all_batches){
    # param_df = NULL
    rmse_df = NULL
    k_df = NULL
    for (b in all_batches){
        if (nchar(b) > 20){
            r = ProcessBatch(b)
            batch_rmse_df = r$rmse_df
            batch_k_df = r$rmse_at_k_df
            # batch_params = r$params
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
DATA_PATH = "../../data/replicants/"
all_files = list.files(DATA_PATH)
all_batches = SimplifyFiles(all_files)

## Analyze ##
r = ProcessAllBatches(all_batches)
k_df = r$k_df
rmse_df = r$rmse_df

write.csv(k_df, "../../data/k_df.csv")
write.csv(rmse_df, "../../data/rmse_df.csv")
