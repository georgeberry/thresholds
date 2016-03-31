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

# strips the number of the run
SimpleFilename = function(filename){
    s = str_replace_all(filename, "__", "~")
    s = str_split(s, "_")
    s = s[[1]][1]
    s = str_replace_all(s, "~", "__")
    return(s)
}

SimplifyFiles = function(file_vector){
    simplified_files = c()
    for (f in file_vector){
        f_simple = SimpleFilename(f)
        simplified_files = union(simplified_files, c(f_simple))
    }
    return(simplified_files)
}

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
RmseOLS = function(formula, f){
    data = read.csv(f)
    observed_df = data[data$observed == 1,]
    mod = lm(formula, data=observed_df)
    rmse = CalcRmse(data$threshold_ceil, predict(mod, data))
    return(rmse)
}

RmseTobit = function(formula, f){
    data = read.csv(f)
    observed_df = data[data$observed == 1,]
    mod = tobit(formula, left=0, right=Inf, dist="gaussian", data=observed_df)
    rmse = CalcRmse(data$threshold_ceil, predict(mod, data))
    return(rmse)
}

# can create a param + rmse line here, with rmse variance
BatchRmse = function(all_batch_files, formula){
    rmse_df = data.frame(rmse_ols = numeric(0), rmse_tobit = numeric(0))
    for (f in all_batch_files){
        rmse_ols = RmseOLS(formula, f)
        rmse_tobit = RmseTobit(formula, f)
        rmse_df = rbind(rmse_df, data.frame(rmse_ols = rmse_ols, rmse_tobit = rmse_tobit))
    }
    # mean and standard error here
}

# want to summarize the 100 runs at k obs in a df
# can do my own sd at each k val
BatchRmseAtK = function(batch_name){
    rmse_at_k_df =
    for (f in all_batch_files){
        rmse_at_k_obs = RmseAtKObs(f)
    }
    return(rmse_at_k_df)
}

# gives RMSE at number obs (maybe every 10?)
RmseAtKObs = function(f){

}

ProcessBatch = function(batch_name){
    param_df = ParseParams(batch_name)
    all_batch_files = GetAllRuns(batch_name)
    rmse_df = BatchRmse(all_batch_files)
    rmse_at_k_df = BatchRmseAtK(all_batch_files)
}


## Prep Files ##
DATA_PATH = "../data/"
all_files = list.files(DATA_PATH)
print(all_files)
file_batches = SimplifyFiles(all_files)
print(file_batches)
## Analyze ##
